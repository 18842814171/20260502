`include "mycpu.h"

// LoongArch-C1 实验子集：addi.w lu12i.w add.w st.w ld.w bne
module id_stage(
    input                          clk           ,
    input                          reset         ,
    input                          es_allowin    ,
    output                         ds_allowin    ,
    input                          fs_to_ds_valid,
    input  [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus  ,
    output                         ds_to_es_valid,
    output [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus  ,
    output [`BR_BUS_WD       -1:0] br_bus        ,
    input  [`WS_TO_RF_BUS_WD -1:0] ws_to_rf_bus  ,

    input                          es_to_ds_load_op,
    input  [ 4:0]                  es_to_ds_dest,
    input  [31:0]                  es_to_ds_data,
    input                          ms_to_ds_load_op,
    input  [ 4:0]                  ms_to_ds_dest,
    input  [31:0]                  ms_to_ds_data,
    input  [ 4:0]                  ws_to_ds_dest,
    input  [31:0]                  ws_to_ds_data
);

wire        br_taken;
wire        br_stall;
wire [31:0] br_target;

wire [31:0] ds_pc;
wire [31:0] ds_inst;

reg         ds_valid;
wire        ds_ready_go;

wire [11:0] alu_op;
wire        load_op;
wire        src1_is_pc;
wire        src2_is_imm;
wire        src2_is_4;
wire        res_from_mem;
wire        gr_we;
wire        mem_we;
wire        src_reg_is_rd;
wire [4:0]  dest;
wire [31:0] rj_value;
wire [31:0] rkd_value;
wire [31:0] imm;
wire [31:0] br_offs;
wire        mem_byte_op;

wire [ 5:0] op_31_26;
wire [ 3:0] op_25_22;
wire [ 1:0] op_21_20;
wire [ 4:0] op_19_15;
wire [ 4:0] rd;
wire [ 4:0] rj;
wire [ 4:0] rk;
wire [11:0] i12;
wire [19:0] i20;
wire [15:0] i16;

wire [63:0] op_31_26_d;
wire [15:0] op_25_22_d;
wire [ 3:0] op_21_20_d;
wire [31:0] op_19_15_d;

wire inst_add_w;
wire inst_addi_w;
wire inst_ld_w;
wire inst_st_w;
wire inst_bne;
wire inst_lu12i_w;

wire need_si20;

wire [4:0] rf_raddr1;
wire [31:0] rf_rdata1;
wire [4:0] rf_raddr2;
wire [31:0] rf_rdata2;

wire rf_we;
wire [4:0] rf_waddr;
wire [31:0] rf_wdata;

wire src_no_rj;
wire src_no_rk;
wire src_no_rd;
wire br_inst;
wire load_stall;
wire rj_eq_rd;
wire rj_use_ex;
wire rkd_use_ex;
wire rj_use_ms;
wire rkd_use_ms;

assign op_31_26  = ds_inst[31:26];
assign op_25_22  = ds_inst[25:22];
assign op_21_20  = ds_inst[21:20];
assign op_19_15  = ds_inst[19:15];

assign rd  = ds_inst[ 4: 0];
assign rj  = ds_inst[ 9: 5];
assign rk  = ds_inst[14:10];
assign i12 = ds_inst[21:10];
assign i20 = ds_inst[24: 5];
assign i16 = ds_inst[25:10];

decoder_6_64 u_dec0(.in(op_31_26), .out(op_31_26_d));
decoder_4_16 u_dec1(.in(op_25_22), .out(op_25_22_d));
decoder_2_4  u_dec2(.in(op_21_20), .out(op_21_20_d));
decoder_5_32 u_dec3(.in(op_19_15), .out(op_19_15_d));

assign inst_add_w   = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h00];
assign inst_addi_w  = op_31_26_d[6'h00] & op_25_22_d[4'ha];
assign inst_ld_w    = op_31_26_d[6'h0a] & op_25_22_d[4'h2];
assign inst_st_w    = op_31_26_d[6'h0a] & op_25_22_d[4'h6];
assign inst_bne     = op_31_26_d[6'h17];
assign inst_lu12i_w = op_31_26_d[6'h05] & ~ds_inst[25];

assign alu_op[ 0] = inst_add_w | inst_addi_w | inst_ld_w | inst_st_w;
assign alu_op[ 1] = 1'b0;
assign alu_op[ 2] = 1'b0;
assign alu_op[ 3] = 1'b0;
assign alu_op[ 4] = 1'b0;
assign alu_op[ 5] = 1'b0;
assign alu_op[ 6] = 1'b0;
assign alu_op[ 7] = 1'b0;
assign alu_op[ 8] = 1'b0;
assign alu_op[ 9] = 1'b0;
assign alu_op[10] = 1'b0;
assign alu_op[11] = inst_lu12i_w;

assign need_si20 = inst_lu12i_w;

assign imm = need_si20 ? {{12{i20[19]}}, i20[19:0], 12'b0} : {{20{i12[11]}}, i12[11:0]};

assign br_offs = {{14{i16[15]}}, i16[15:0], 2'b0};

assign src_reg_is_rd = inst_bne | inst_st_w;
assign src1_is_pc    = 1'b0;
assign src2_is_imm   = inst_addi_w | inst_ld_w | inst_st_w | inst_lu12i_w;
assign src2_is_4     = 1'b0;

assign load_op      = inst_ld_w;
assign res_from_mem = inst_ld_w;
assign gr_we        = ~inst_st_w & ~inst_bne;
assign mem_we       = inst_st_w;
assign dest         = rd;
assign mem_byte_op  = 1'b0;

assign rf_raddr1 = rj;
assign rf_raddr2 = src_reg_is_rd ? rd : rk;

regfile u_regfile(
    .clk    (clk      ),
    .raddr1 (rf_raddr1),
    .rdata1 (rf_rdata1),
    .raddr2 (rf_raddr2),
    .rdata2 (rf_rdata2),
    .we     (rf_we    ),
    .waddr  (rf_waddr ),
    .wdata  (rf_wdata )
);

assign src_no_rj = inst_lu12i_w;
assign src_no_rk = inst_addi_w | inst_ld_w | inst_st_w | inst_lu12i_w | inst_bne;
assign src_no_rd = ~(inst_st_w | inst_bne);

assign rj_value = ((rj == es_to_ds_dest) && (es_to_ds_dest != 5'd0)) ? es_to_ds_data :
                  ((rj == ms_to_ds_dest) && (ms_to_ds_dest != 5'd0)) ? ms_to_ds_data :
                  ((rj == ws_to_ds_dest) && (ws_to_ds_dest != 5'd0)) ? ws_to_ds_data :
                                                                        rf_rdata1;

assign rkd_value = ((rf_raddr2 == es_to_ds_dest) && (es_to_ds_dest != 5'd0)) ? es_to_ds_data :
                   ((rf_raddr2 == ms_to_ds_dest) && (ms_to_ds_dest != 5'd0)) ? ms_to_ds_data :
                   ((rf_raddr2 == ws_to_ds_dest) && (ws_to_ds_dest != 5'd0)) ? ws_to_ds_data :
                   rf_rdata2;

assign rj_use_ex  = ~src_no_rj && (rj != 5'd0) && (rj == es_to_ds_dest);
assign rkd_use_ex = (~src_no_rk || ~src_no_rd) && (rf_raddr2 != 5'd0) && (rf_raddr2 == es_to_ds_dest);
assign rj_use_ms  = ~src_no_rj && (rj != 5'd0) && (rj == ms_to_ds_dest);
assign rkd_use_ms = (~src_no_rk || ~src_no_rd) && (rf_raddr2 != 5'd0) && (rf_raddr2 == ms_to_ds_dest);
assign load_stall = (es_to_ds_load_op && (rj_use_ex || rkd_use_ex)) ||
                    (ms_to_ds_load_op && (rj_use_ms || rkd_use_ms));

assign rj_eq_rd   = (rj_value == rkd_value);
assign br_inst    = inst_bne;
assign br_taken   = (inst_bne && !rj_eq_rd) && ds_valid && ~load_stall;
assign br_stall   = br_inst && ds_valid && load_stall;
assign br_target  = ds_pc + br_offs;

assign br_bus = {br_stall, br_taken, br_target};

reg [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus_r;

assign {ds_inst, ds_pc} = fs_to_ds_bus_r;

assign {rf_we, rf_waddr, rf_wdata} = ws_to_rf_bus;

assign ds_to_es_bus = {alu_op       ,
                       load_op      ,
                       src1_is_pc   ,
                       src2_is_imm  ,
                       src2_is_4    ,
                       gr_we        ,
                       mem_we       ,
                       dest         ,
                       imm          ,
                       rj_value     ,
                       rkd_value    ,
                       ds_pc        ,
                       res_from_mem ,
                       mem_byte_op
                      };

assign ds_ready_go    = ds_valid & ~load_stall;
assign ds_allowin     = !ds_valid || (ds_ready_go && es_allowin);
assign ds_to_es_valid  = ds_valid && ds_ready_go;

always @(posedge clk) begin
    if (reset) begin
        ds_valid <= 1'b0;
        fs_to_ds_bus_r <= {`FS_TO_DS_BUS_WD{1'b0}};
    end
    else if (br_taken && ds_ready_go) begin
        ds_valid <= 1'b0;
    end
    else if (ds_allowin) begin
        ds_valid <= fs_to_ds_valid;
    end

    if (!reset && fs_to_ds_valid && ds_allowin) begin
        fs_to_ds_bus_r <= fs_to_ds_bus;
    end
end

endmodule
