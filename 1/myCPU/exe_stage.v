`include "mycpu.h"

module exe_stage(
    input                          clk           ,
    input                          reset         ,
    //allowin
    input                          ms_allowin    ,
    output                         es_allowin    ,
    //from ds
    input                          ds_to_es_valid,
    input  [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus  ,
    //to ms
    output                         es_to_ms_valid,
    output [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus  ,

    // ????????????????
    output [ 4:0] es_to_ds_dest,
    output [31:0] es_to_ds_data,
    output        es_to_ds_load_op,
    
    // data sram interface(write)
    output        data_sram_en   ,
    output [ 3:0] data_sram_we   ,
    output [31:0] data_sram_addr ,
    output [31:0] data_sram_wdata
);

reg         es_valid      ;
wire        es_ready_go   ;

reg  [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus_r;

wire [11:0] alu_op      ;
wire        es_load_op;
wire        src1_is_pc;
wire        src2_is_imm;
wire        src2_is_4;
wire        res_from_mem;
wire        dst_is_r1;
wire        gr_we;
wire        es_mem_we;
wire        mem_byte_op; // 改动
wire [4: 0] dest;
wire [31:0] rj_value;
wire [31:0] rkd_value;
wire [31:0] imm;
wire [31:0] es_pc;


assign {alu_op,
        es_load_op,
        src1_is_pc,
        src2_is_imm,
        src2_is_4,
        gr_we,
        es_mem_we,
        dest,
        imm,
        rj_value,
        rkd_value,
        es_pc,
        res_from_mem,
        mem_byte_op // 改动
       } = ds_to_es_bus_r;

wire [31:0] alu_src1   ;
wire [31:0] alu_src2   ;
wire [31:0] alu_result ;



assign es_to_ds_dest    = (es_valid === 1'b1) ? dest       : 5'd0;  // 改动
assign es_to_ds_data    = (es_valid === 1'b1) ? alu_result : 32'd0; // 改动
assign es_to_ds_load_op = (es_valid === 1'b1) ? es_load_op : 1'b0;  // 改动

// ES->MS bus (MSB..LSB):
// {res_from_mem, es_mem_we, gr_we, dest[4:0], alu_result[31:0], rkd_value[31:0], es_pc[31:0], mem_byte_op}
assign es_to_ms_bus = {res_from_mem,
                       es_mem_we,
                       gr_we,
                       dest,
                       alu_result,
                       rkd_value,
                       es_pc,
                       mem_byte_op
                      };

assign es_ready_go    = 1'b1;
assign es_allowin     = !es_valid || es_ready_go && ms_allowin;
assign es_to_ms_valid =  es_valid && es_ready_go;
always @(posedge clk) begin
    if (reset) begin
        es_valid <= 1'b0;
    end
    else if (es_allowin) begin
        es_valid <= ds_to_es_valid;
    end

    if (ds_to_es_valid && es_allowin) begin
        ds_to_es_bus_r <= ds_to_es_bus;
    end
end

assign alu_src1 = src1_is_pc  ? es_pc  : rj_value;
assign alu_src2 = src2_is_imm ? imm : rkd_value;

alu u_alu(
    .alu_op     (alu_op    ),
    .alu_src1   (alu_src1  ),
    .alu_src2   (alu_src2  ),
    .alu_result (alu_result)
    );

assign data_sram_en    = es_valid && (es_mem_we || es_load_op);
assign data_sram_we    = (es_mem_we && es_valid) ? (mem_byte_op ? (4'b0001 << alu_result[1:0]) : 4'hf) : 4'h0; // 改动
assign data_sram_addr  = alu_result;
assign data_sram_wdata = mem_byte_op ? {4{rkd_value[7:0]}} : rkd_value; // 改动



endmodule
