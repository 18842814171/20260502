//`default_nettype none
// ThinPAD 顶层：对接 myCPU 与板载 BaseRAM / ExtRAM。
// 与实验《要求》一致：
// - 虚拟地址 0x8000_0000 ~ 0x803F_FFFF → BaseRAM（指令与数据均可）
// - 虚拟地址 0x8040_0000 ~ 0x807F_FFFF → ExtRAM
// - 复位键 reset_btn 为高时 CPU 处于复位（mycpu_top.resetn = ~reset_btn）
// - 取指/数据端口争用 BaseRAM 时，用 if_stall 暂停取指，避免总线冲突

module thinpad_top(
    input wire clk_50M,
    input wire clk_11M0592,

    input wire clock_btn,
    input wire reset_btn,

    inout wire [31:0] base_ram_data,
    output wire [19:0] base_ram_addr,
    output wire [3:0]  base_ram_be_n,
    output wire        base_ram_ce_n,
    output wire        base_ram_oe_n,
    output wire        base_ram_we_n,

    inout wire [31:0] ext_ram_data,
    output wire [19:0] ext_ram_addr,
    output wire [3:0]  ext_ram_be_n,
    output wire        ext_ram_ce_n,
    output wire        ext_ram_oe_n,
    output wire        ext_ram_we_n,

    output wire txd,
    input  wire rxd
);

wire        inst_sram_en;
wire [3:0]  inst_sram_wen;
wire [31:0] inst_sram_addr;
wire [31:0] inst_sram_wdata;
wire [31:0] inst_sram_rdata;

wire        data_sram_en;
wire [3:0]  data_sram_wen;
wire [31:0] data_sram_addr;
wire [31:0] data_sram_wdata;
wire [31:0] data_sram_rdata;

wire        data_sram_we_any;
wire        uart_data_addr_hit;
wire        uart_stat_addr_hit;
wire        data_access_uart;
wire        data_access_base;
wire        data_access_ext;
wire        ext_write_en;
wire        ext_read_en;
wire [7:0]  uart_wbyte;
reg         uart_start;
wire        uart_busy;
wire        uart_rx_ready;
wire [7:0]  uart_rbyte;
wire        uart_rx_clear;
wire [31:0] uart_rdata;
wire [31:0] base_rdata;
wire [31:0] ext_rdata;
wire        base_data_write_en;

wire [31:0] cpu_debug_wb_pc;
wire [3:0]  cpu_debug_wb_rf_we;
wire [4:0]  cpu_debug_wb_rf_wnum;
wire [31:0] cpu_debug_wb_rf_wdata;

async_transmitter #(
    .ClkFrequency(50000000),
    .Baud(9600)
) u_async_tx (
    .rst       (reset_btn),
    .clk       (clk_50M),
    .TxD_start (uart_start),
    .TxD_data  (uart_last_byte),
    .TxD       (txd),
    .TxD_busy  (uart_busy)
);

async_receiver #(
    .ClkFrequency(50000000),
    .Baud(9600)
) u_async_rx (
    .clk           (clk_50M),
    .RxD           (rxd),
    .RxD_data_ready(uart_rx_ready),
    .RxD_clear     (uart_rx_clear),
    .RxD_data      (uart_rbyte)
);

assign data_sram_we_any   = |data_sram_wen;
assign uart_data_addr_hit = (data_sram_addr[21:0] === 22'h1003f8);
assign uart_stat_addr_hit = (data_sram_addr[21:0] === 22'h1003fc);
assign data_access_uart   = (data_sram_en === 1'b1) && (uart_data_addr_hit || uart_stat_addr_hit);
assign data_access_base   = (data_sram_en === 1'b1) &&
                            (data_sram_addr >= 32'h8000_0000) &&
                            (data_sram_addr <  32'h8040_0000);
assign data_access_ext    = (data_sram_en === 1'b1) &&
                            (data_sram_addr >= 32'h8040_0000) &&
                            (data_sram_addr <  32'h8080_0000);
assign ext_write_en       = data_access_ext && data_sram_we_any;
assign ext_read_en        = data_access_ext && ~data_sram_we_any;

assign uart_wbyte =
    data_sram_wen[0] ? data_sram_wdata[7:0]   :
    data_sram_wen[1] ? data_sram_wdata[15:8]  :
    data_sram_wen[2] ? data_sram_wdata[23:16] :
    data_sram_wen[3] ? data_sram_wdata[31:24] :
                       8'h00;

assign uart_rx_clear = (data_access_uart === 1'b1) && (uart_data_addr_hit === 1'b1) && (data_sram_we_any === 1'b0);
wire uart_rx_ready_clean = (uart_rx_ready === 1'b1);
localparam integer UART_FIFO_DEPTH = 16;
reg [7:0] uart_fifo [0:UART_FIFO_DEPTH-1];
reg [3:0] uart_fifo_wptr;
reg [3:0] uart_fifo_rptr;
reg [4:0] uart_fifo_count;
wire      uart_fifo_empty = (uart_fifo_count == 5'd0);
wire      uart_fifo_full  = (uart_fifo_count == UART_FIFO_DEPTH);
wire      uart_tx_ready   = ~uart_fifo_full;
assign uart_rdata = uart_stat_addr_hit ? {30'b0, uart_rx_ready_clean, uart_tx_ready} :
                    uart_data_addr_hit ? {24'b0, uart_rbyte} :
                    32'b0;

wire uart_write_level = data_access_uart && uart_data_addr_hit && data_sram_we_any;
wire uart_fire = uart_write_level;
reg [7:0] uart_last_byte;
reg       uart_tx_valid;
always @(posedge clk_50M) begin
    if (reset_btn) begin
        uart_last_byte <= 8'h00;
        uart_fifo_wptr <= 4'd0;
        uart_fifo_rptr <= 4'd0;
        uart_fifo_count <= 5'd0;
        uart_tx_valid  <= 1'b0;
        uart_start     <= 1'b0;
    end else begin
        uart_start <= 1'b0;

        if (uart_fire && !uart_fifo_full) begin
            uart_fifo[uart_fifo_wptr] <= uart_wbyte;
            uart_fifo_wptr <= uart_fifo_wptr + 4'd1;
        end

        if (!uart_tx_valid && !uart_fifo_empty) begin
            uart_last_byte <= uart_fifo[uart_fifo_rptr];
            uart_fifo_rptr <= uart_fifo_rptr + 4'd1;
            uart_tx_valid  <= 1'b1;
        end

        if (uart_tx_valid && !uart_busy) begin
            uart_start    <= 1'b1;
            uart_tx_valid <= 1'b0;
        end

        case ({uart_fire && !uart_fifo_full, !uart_tx_valid && !uart_fifo_empty})
            2'b10: uart_fifo_count <= uart_fifo_count + 5'd1;
            2'b01: uart_fifo_count <= uart_fifo_count - 5'd1;
            default: uart_fifo_count <= uart_fifo_count;
        endcase
    end
end

mycpu_top cpu (
    .clk              (clk_50M),
    .resetn           (~reset_btn),
    .if_stall         (data_access_base),

    .inst_sram_en     (inst_sram_en),
    .inst_sram_we     (inst_sram_wen),
    .inst_sram_addr   (inst_sram_addr),
    .inst_sram_wdata  (inst_sram_wdata),
    .inst_sram_rdata  (inst_sram_rdata),

    .data_sram_en     (data_sram_en),
    .data_sram_we     (data_sram_wen),
    .data_sram_addr   (data_sram_addr),
    .data_sram_wdata  (data_sram_wdata),
    .data_sram_rdata  (data_sram_rdata),

    .debug_wb_pc       (cpu_debug_wb_pc),
    .debug_wb_rf_we    (cpu_debug_wb_rf_we),
    .debug_wb_rf_wnum  (cpu_debug_wb_rf_wnum),
    .debug_wb_rf_wdata (cpu_debug_wb_rf_wdata)
);

assign inst_sram_rdata = base_ram_data;
assign base_rdata = base_ram_data;
assign base_data_write_en = data_access_base && data_sram_we_any;
assign base_ram_data = base_data_write_en ? data_sram_wdata : 32'bz;
assign base_ram_addr = data_access_base ? data_sram_addr[21:2] : inst_sram_addr[21:2];
assign base_ram_be_n = base_data_write_en ? ~data_sram_wen : 4'h0;
assign base_ram_ce_n = ((inst_sram_en === 1'b1) || (data_access_base === 1'b1)) ? 1'b0 : 1'b1;
assign base_ram_oe_n = 1'b0;
assign base_ram_we_n = base_data_write_en ? 1'b0 : 1'b1;

assign ext_ram_data = ~ext_ram_we_n ? data_sram_wdata : 32'bz;
assign ext_rdata = ext_ram_data;
assign data_sram_rdata = data_access_uart ? uart_rdata :
                         data_access_base ? base_rdata :
                         ext_rdata;
assign ext_ram_addr  = data_sram_addr[21:2];

assign ext_ram_be_n = (~ext_ram_we_n) ? ~data_sram_wen : 4'b0000;
assign ext_ram_ce_n = data_access_ext ? 1'b0 : 1'b1;
assign ext_ram_oe_n = ext_read_en ? 1'b0 : 1'b1;
assign ext_ram_we_n = ext_write_en ? 1'b0 : 1'b1;

endmodule
