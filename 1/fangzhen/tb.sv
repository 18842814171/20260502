`timescale 1ns / 1ps
// 仿真顶层：加载 BaseRAM 测试 bin，复位后运行 CPU；与实验《要求》一致可核对 ExtRAM 结果。
// BaseRAM: 虚拟 0x8000_0000~0x803F_FFFF；ExtRAM: 0x8040_0000~0x807F_FFFF。

module tb;

reg clk = 1'b0;
always #10 clk = ~clk;

wire clk_11M0592 = 1'b0;

reg clock_btn = 1'b0;
reg reset_btn   = 1'b1;

wire txd;
wire rxd;

wire [31:0] base_ram_data;
wire [19:0] base_ram_addr;
wire [3:0]  base_ram_be_n;
wire        base_ram_ce_n;
wire        base_ram_oe_n;
wire        base_ram_we_n;

wire [31:0] ext_ram_data;
wire [19:0] ext_ram_addr;
wire [3:0]  ext_ram_be_n;
wire        ext_ram_ce_n;
wire        ext_ram_oe_n;
wire        ext_ram_we_n;

parameter BASE_RAM_INIT_FILE = "E:/fangzhen/lab2/lab2.bin";
parameter RUN_AFTER_RESET_NS = 5000000;

assign rxd = 1'b1;

thinpad_top dut (
    .clk_50M      (clk),
    .clk_11M0592  (clk_11M0592),
    .clock_btn    (clock_btn),
    .reset_btn    (reset_btn),
    .txd          (txd),
    .rxd          (rxd),
    .base_ram_data(base_ram_data),
    .base_ram_addr(base_ram_addr),
    .base_ram_ce_n(base_ram_ce_n),
    .base_ram_oe_n(base_ram_oe_n),
    .base_ram_we_n(base_ram_we_n),
    .base_ram_be_n(base_ram_be_n),
    .ext_ram_data (ext_ram_data),
    .ext_ram_addr (ext_ram_addr),
    .ext_ram_ce_n (ext_ram_ce_n),
    .ext_ram_oe_n (ext_ram_oe_n),
    .ext_ram_we_n (ext_ram_we_n),
    .ext_ram_be_n (ext_ram_be_n)
);

sram_model base1 (
    .DataIO  (base_ram_data[15:0]),
    .Address (base_ram_addr[19:0]),
    .OE_n    (base_ram_oe_n),
    .CE_n    (base_ram_ce_n),
    .WE_n    (base_ram_we_n),
    .LB_n    (base_ram_be_n[0]),
    .UB_n    (base_ram_be_n[1])
);
sram_model base2 (
    .DataIO  (base_ram_data[31:16]),
    .Address (base_ram_addr[19:0]),
    .OE_n    (base_ram_oe_n),
    .CE_n    (base_ram_ce_n),
    .WE_n    (base_ram_we_n),
    .LB_n    (base_ram_be_n[2]),
    .UB_n    (base_ram_be_n[3])
);
sram_model ext1 (
    .DataIO  (ext_ram_data[15:0]),
    .Address (ext_ram_addr[19:0]),
    .OE_n    (ext_ram_oe_n),
    .CE_n    (ext_ram_ce_n),
    .WE_n    (ext_ram_we_n),
    .LB_n    (ext_ram_be_n[0]),
    .UB_n    (ext_ram_be_n[1])
);
sram_model ext2 (
    .DataIO  (ext_ram_data[31:16]),
    .Address (ext_ram_addr[19:0]),
    .OE_n    (ext_ram_oe_n),
    .CE_n    (ext_ram_ce_n),
    .WE_n    (ext_ram_we_n),
    .LB_n    (ext_ram_be_n[2]),
    .UB_n    (ext_ram_be_n[3])
);

reg [31:0] init_word_array [0:1048575];
integer init_fid, init_word_cnt;

initial begin
    init_word_cnt = 0;
    init_fid = $fopen(BASE_RAM_INIT_FILE, "rb");
    if (init_fid == 0) begin
        $display("ERROR: cannot open BaseRAM init file: %s", BASE_RAM_INIT_FILE);
    end else begin
        init_word_cnt = $fread(init_word_array, init_fid);
        init_word_cnt = init_word_cnt / 4;
        $fclose(init_fid);
    end
    $display("BaseRAM init words: %0d", init_word_cnt);
    begin : load_base
        integer i;
        for (i = 0; i < init_word_cnt; i = i + 1) begin
            base1.mem_array0[i] = init_word_array[i][24+:8];
            base1.mem_array1[i] = init_word_array[i][16+:8];
            base2.mem_array0[i] = init_word_array[i][8+:8];
            base2.mem_array1[i] = init_word_array[i][0+:8];
        end
    end
    // ExtRAM 不预置文件（与《要求》：先清空/重置 ExtRAM 再跑测试 一致）
end

integer      dump_k;
reg [19:0]   dbg_ext_wr_addr;
reg [3:0]    dbg_ext_wr_be_n;
reg [31:0]   dbg_ext_wr_wdata;

initial begin
    reset_btn = 1'b1;
    #2000;
    reset_btn = 1'b0;
    #(RUN_AFTER_RESET_NS);
    $display("--- ExtRAM physical word dump [0:64] (对照《要求》ExtRAM 字节 0x0~0x100) ---");
    for (dump_k = 0; dump_k <= 64; dump_k = dump_k + 1) begin
        $display("  ext_word[%0d] = %08h", dump_k, {
            ext1.mem_array0[dump_k],
            ext1.mem_array1[dump_k],
            ext2.mem_array0[dump_k],
            ext2.mem_array1[dump_k]
        });
    end
    $display("TB done.");
    $finish;
end

always @(posedge clk) begin
    if (~ext_ram_ce_n && ~ext_ram_we_n) begin
        dbg_ext_wr_addr   = ext_ram_addr;
        dbg_ext_wr_be_n   = ext_ram_be_n;
        dbg_ext_wr_wdata  = ext_ram_data;
        #1;
        $display("EXT_WR word_addr=%05h be_n=%b wdata=%08h",
                 dbg_ext_wr_addr, dbg_ext_wr_be_n, dbg_ext_wr_wdata);
    end
end

endmodule
