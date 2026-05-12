`include "mycpu.h"

module mem_stage(
    input                          clk           ,
    input                          reset         ,
    //allowin
    input                          ws_allowin    ,
    output                         ms_allowin    ,
    //from es
    input                          es_to_ms_valid,
    input  [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus  ,
    //to ws
    output                         ms_to_ws_valid,
    output [`MS_TO_WS_BUS_WD -1:0] ms_to_ws_bus  ,
    
    // ????????????????
    output [ 4                 :0] ms_to_ds_dest ,
    output [31:0]               ms_to_ds_data ,
    output                       ms_to_ds_load_op, // 改动

    // data sram interface (driven by MEM stage for timing alignment)
    output                       data_sram_en,
    output [ 3:0]                data_sram_we,
    output [31:0]                data_sram_addr,
    output [31:0]                data_sram_wdata,
    
    //from data-sram
    input  [31                 :0] data_sram_rdata
);

reg         ms_valid;
wire        ms_ready_go;
reg         ms_waiting;

reg [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus_r;
wire        ms_res_from_mem;
wire        ms_mem_we;
wire        ms_gr_we;
wire [ 4:0] ms_dest;
wire [31:0] ms_alu_result;
wire [31:0] ms_rkd_value;    // 改动
wire [31:0] ms_pc;
wire        ms_mem_byte_op;  // 改动

wire [31:0] mem_result;
wire [31:0] ms_final_result;
reg  [31:0] ms_load_data_r;


assign {ms_res_from_mem,
        ms_mem_we,
        ms_gr_we,
        ms_dest,
        ms_alu_result,
        ms_rkd_value,
        ms_pc,
        ms_mem_byte_op
       } = es_to_ms_bus_r;

assign ms_to_ws_bus = {ms_gr_we       ,  //69:69
                       ms_dest        ,  //68:64
                       ms_final_result,  //63:32
                       ms_pc             //31:0
                      };

// For load ops, stall MEM for 1 extra cycle so data_sram_rdata becomes valid
// while EXE stage holds address stable (ms_allowin deasserts -> es_allowin stalls).
assign ms_ready_go    = ms_res_from_mem ? ~ms_waiting : 1'b1;
assign ms_allowin     = !ms_valid || ms_ready_go && ws_allowin;
assign ms_to_ws_valid = ms_valid && ms_ready_go;
always @(posedge clk) begin
    if (reset) begin
        ms_valid <= 1'b0;
        ms_waiting <= 1'b0;
        ms_load_data_r <= 32'b0;
        es_to_ms_bus_r <= {`ES_TO_MS_BUS_WD{1'b0}};
    end
    else if (ms_allowin) begin
        ms_valid <= es_to_ms_valid;
        // If a load enters MEM, start a 1-cycle wait (res_from_mem is MSB of es_to_ms_bus).
        ms_waiting <= es_to_ms_valid && es_to_ms_bus[`ES_TO_MS_BUS_WD-1];
    end
    else if (ms_valid && ms_res_from_mem && ms_waiting) begin
        // End of the wait cycle: capture stable read data, then release next cycle.
        ms_load_data_r <= data_sram_rdata;
        ms_waiting <= 1'b0;
    end

    if (!reset && es_to_ms_valid && ms_allowin) begin
        es_to_ms_bus_r  <= es_to_ms_bus; // 改动
    end
end
// Non-load: do not use data_sram_rdata here (may be Z); avoids X/Z in mem_byte cone.
assign mem_result   = ms_res_from_mem ? ms_load_data_r : 32'b0;
wire [7:0] mem_byte; // 改动
assign mem_byte = (ms_alu_result[1:0] == 2'b00) ? mem_result[7:0]   :
                  (ms_alu_result[1:0] == 2'b01) ? mem_result[15:8]  :
                  (ms_alu_result[1:0] == 2'b10) ? mem_result[23:16] :
                                                  mem_result[31:24]; // 改动
wire [31:0] mem_byte_sext; // 改动
assign mem_byte_sext = {{24{mem_byte[7]}}, mem_byte}; // 改动

assign ms_final_result = ms_res_from_mem ? (ms_mem_byte_op ? mem_byte_sext : mem_result) : ms_alu_result; // 改动

assign ms_to_ds_dest = (ms_valid === 1'b1) ? ms_dest         : 5'd0;  // 改动
assign ms_to_ds_data = (ms_valid === 1'b1) ? ms_final_result : 32'd0; // 改动
assign ms_to_ds_load_op = (ms_valid === 1'b1) ? ms_res_from_mem : 1'b0; // 改动

// ---- drive external data-sram from MEM stage ----
assign data_sram_en   = ms_valid && (ms_mem_we || ms_res_from_mem);
assign data_sram_addr = ms_alu_result;
assign data_sram_wdata = ms_mem_byte_op ? {4{ms_rkd_value[7:0]}} : ms_rkd_value;
assign data_sram_we   = (ms_valid && ms_mem_we) ?
                        (ms_mem_byte_op ? (4'b0001 << ms_alu_result[1:0]) : 4'hf) :
                        4'h0;

endmodule
