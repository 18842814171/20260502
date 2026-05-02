//`default_nettype none

module thinpad_top(
    input wire clk_50M,           //50MHz ?������
    input wire clk_11M0592,       //11.0592MHz ?�����?���??���

    input wire clock_btn,         //BTN5�?�?�?�?���?����������������??1
    input wire reset_btn,         //BTN6�?���?��?���?����������������??1

    //BaseRAM�?�
    inout wire[31:0] base_ram_data,  //BaseRAM���?���8?��CPLD���?���������
    output wire[19:0] base_ram_addr, //BaseRAM��?
    output wire[3:0] base_ram_be_n,  //BaseRAM�?�?�?�����?�������?���?�?�?��?���?0
    output wire base_ram_ce_n,       //BaseRAM??������?
    output wire base_ram_oe_n,       //BaseRAM��?�?�����?
    output wire base_ram_we_n,       //BaseRAM??�?�����?

    //ExtRAM�?�
    inout wire[31:0] ext_ram_data,  //ExtRAM����
    output wire[19:0] ext_ram_addr, //ExtRAM��?
    output wire[3:0] ext_ram_be_n,  //ExtRAM�?�?�?�����?�������?���?�?�?��?���?0
    output wire ext_ram_ce_n,       //ExtRAM??������?
    output wire ext_ram_oe_n,       //ExtRAM��?�?�����?
    output wire ext_ram_we_n,       //ExtRAM??�?�����?

    //?�������?�
    output wire txd,  //?�����?��?�
    input  wire rxd   //?�����?��?�
);
//---------------------------------mycpu--------------------------------

wire        inst_sram_en;
wire [3 :0] inst_sram_wen;
wire [31:0] inst_sram_addr;
wire [31:0] inst_sram_wdata;
wire [31:0] inst_sram_rdata;
    
wire        data_sram_en;
wire [3 :0] data_sram_wen;
wire [31:0] data_sram_addr;
wire [31:0] data_sram_wdata;
wire [31:0] data_sram_rdata;

wire       data_sram_we_any;
wire       uart_data_addr_hit;
wire       uart_stat_addr_hit;
wire       data_access_uart;
wire       data_access_base;
wire       data_access_ext;
wire       ext_write_en;
wire       ext_read_en;
wire [7:0] uart_wbyte;
reg        uart_start;
wire       uart_busy;
wire       uart_rx_ready;
wire [7:0] uart_rbyte;
wire       uart_rx_clear;
wire [31:0] uart_rdata;
wire [31:0] base_rdata;
wire [31:0] ext_rdata;
wire       base_data_write_en;

async_transmitter #(
    .ClkFrequency(50000000),
    .Baud(9600)
) u_async_tx (
    .rst      (reset_btn ),
    .clk      (clk_50M   ),
    .TxD_start(uart_start ),
    .TxD_data (uart_last_byte),
    .TxD      (txd        ),
    .TxD_busy (uart_busy  )
);

async_receiver #(
    .ClkFrequency(50000000),
    .Baud(9600)
) u_async_rx (
    .clk          (clk_50M      ),
    .RxD          (rxd          ),
    .RxD_data_ready(uart_rx_ready),
    .RxD_clear    (uart_rx_clear),
    .RxD_data     (uart_rbyte   )
);

assign data_sram_we_any   = |data_sram_wen;
// Decode UART by low 22 bits so it matches current SRAM address slicing [21:2].
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

// UART status: bit0=tx_ready, bit1=rx_ready
assign uart_rx_clear = (data_access_uart === 1'b1) && (uart_data_addr_hit === 1'b1) && (data_sram_we_any === 1'b0);
// Avoid X-propagation from async_receiver (RxD_data_ready has no reset in this IP).
// Treat unknown as 0 so CPU polling loops behave deterministically in simulation.
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

// Detect CPU write to UART TX register.
// Note: some cores hold the store control for multiple cycles; use edge-detect so
// one store maps to exactly one queued TX byte.
wire uart_write_level = data_access_uart && uart_data_addr_hit && data_sram_we_any;
// uart_write_level may stay high for back-to-back stores in the pipeline.
// Using edge-detect here would drop all but the first byte.
wire uart_fire = uart_write_level;  // accept every cycle with an active store
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
        // default pulse behavior
        uart_start <= 1'b0;

        // Enqueue every committed UART store while FIFO has space.
        if (uart_fire && !uart_fifo_full) begin
            uart_fifo[uart_fifo_wptr] <= uart_wbyte;
            uart_fifo_wptr <= uart_fifo_wptr + 4'd1;
        end

        // First stage: move one FIFO entry into a stable output register.
        if (!uart_tx_valid && !uart_fifo_empty) begin
            uart_last_byte <= uart_fifo[uart_fifo_rptr];
            uart_fifo_rptr <= uart_fifo_rptr + 4'd1;
            uart_tx_valid  <= 1'b1;
        end

        // Second stage: launch only after uart_last_byte has been stable for a full cycle.
        if (uart_tx_valid && !uart_busy) begin
            uart_start    <= 1'b1;
            uart_tx_valid <= 1'b0;
        end

        case ({uart_fire && !uart_fifo_full, !uart_tx_valid && !uart_fifo_empty})
            2'b10: uart_fifo_count <= uart_fifo_count + 5'd1;  // enqueue only
            2'b01: uart_fifo_count <= uart_fifo_count - 5'd1;  // dequeue only
            default: uart_fifo_count <= uart_fifo_count;       // both or neither
        endcase
    end
end
//cpu
mycpu_top cpu(
    .clk              (clk_50M   ),
    .resetn           (~reset_btn),  //low active
    .if_stall         (data_access_base),

    .inst_sram_en     (inst_sram_en   ),
    .inst_sram_we    (inst_sram_wen  ),
    .inst_sram_addr   (inst_sram_addr ),
    .inst_sram_wdata  (inst_sram_wdata),
    .inst_sram_rdata  (inst_sram_rdata),
    
    .data_sram_en     (data_sram_en   ),
    .data_sram_we    (data_sram_wen  ),
    .data_sram_addr   (data_sram_addr ),
    .data_sram_wdata  (data_sram_wdata),
    .data_sram_rdata  (data_sram_rdata)
);





assign inst_sram_rdata = base_ram_data;
assign base_rdata = base_ram_data;
assign base_data_write_en = data_access_base && data_sram_we_any;
assign base_ram_data = base_data_write_en ? data_sram_wdata : 32'bz;
assign base_ram_addr = data_access_base ? data_sram_addr[21:2] : inst_sram_addr[21:2];
assign base_ram_be_n = base_data_write_en ? ~data_sram_wen : 4'h0;
assign base_ram_ce_n = ((inst_sram_en===1'b1) || (data_access_base===1'b1)) ? 1'b0 : 1'b1;
assign base_ram_oe_n = 1'b0;
assign base_ram_we_n = base_data_write_en ? 1'b0 : 1'b1;

//assign ext_ram_data = (data_sram_wen[0]===1)?data_sram_wdata : 32'bz;
assign ext_ram_data = ~ext_ram_we_n ? data_sram_wdata : 32'bz;
assign ext_rdata = ext_ram_data;
assign data_sram_rdata = data_access_uart ? uart_rdata :
                         data_access_base ? base_rdata :
                         ext_rdata;
assign ext_ram_addr  = data_sram_addr[21:2] ;     

assign ext_ram_be_n = (~ext_ram_we_n) ? ~data_sram_wen : 4'b0000;
assign ext_ram_ce_n = data_access_ext ? 1'b0 : 1'b1;
assign ext_ram_oe_n = ext_read_en ? 1'b0 : 1'b1;
assign ext_ram_we_n = ext_write_en ? 1'b0 : 1'b1;

endmodule
