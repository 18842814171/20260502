`include "mycpu.h"

module if_stage(
    input                          clk            ,
    input                          reset          ,
    input                          if_stall       ,
    //allwoin
    input                          ds_allowin     ,
    //brbus
    input  [`BR_BUS_WD       -1:0] br_bus         ,
    //to ds
    output                         fs_to_ds_valid ,
    output [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus   ,
    // inst sram interface
    output        inst_sram_en   ,
    output [ 3:0] inst_sram_we  ,
    output [31:0] inst_sram_addr ,
    output [31:0] inst_sram_wdata,
    input  [31:0] inst_sram_rdata
);

reg         fs_valid;
wire        fs_ready_go;
wire        fs_allowin;
wire        to_fs_valid;

wire [31:0] seq_pc;
wire [31:0] nextpc;

wire         br_taken;
wire [ 31:0] br_target;
//????
wire         br_stall;
wire         br_stall_v; // ???
wire         pre_if_ready_go;
assign {br_stall, br_taken, br_target} = br_bus; //???
assign br_stall_v = (br_stall === 1'b1); // ???

reg [31:0] fs_inst;
reg  [31:0] fs_pc;
assign fs_to_ds_bus = {fs_inst ,
                       fs_pc   };

// pre-IF stage
assign to_fs_valid  = pre_if_ready_go; //???
assign pre_if_ready_go = ~if_stall; // pause IF when data path uses single-port BaseRAM

assign seq_pc       = fs_pc + 3'h4;
// Only treat explicitly-1 as taken; if br_taken is X, stay on seq_pc (avoids PC/inst addr X).
assign nextpc       = (br_taken === 1'b1) ? br_target : seq_pc;

// IF stage
assign fs_ready_go    = ~br_stall_v && ~if_stall;   // ???
assign fs_allowin     = !fs_valid || fs_ready_go && ds_allowin;     // ????????????????
assign fs_to_ds_valid =  fs_valid && fs_ready_go;   
always @(posedge clk) begin
    if (reset) begin
        fs_valid <= 1'b0;
    end
    else if (br_taken === 1'b1) begin
        // Branch target should become the next valid IF result.
        // Clearing fs_valid here drops target PC once and DS observes PC+4.
        fs_valid <= to_fs_valid;
    end
    else if (fs_allowin) begin
        fs_valid <= to_fs_valid;    // ????????
    end
end

always @(posedge clk) begin
    if (reset) begin
        fs_pc <= 32'h7ffffffc;     //trick: to make nextpc be 0x1c000000 during reset 
    end
    else if (to_fs_valid && (fs_allowin || (br_taken === 1'b1))) begin // ???
        fs_pc <= nextpc;
        fs_inst <= inst_sram_rdata;
    end
end

assign inst_sram_en    = to_fs_valid && ((fs_allowin && ~br_stall_v) || (br_taken === 1'b1)) && pre_if_ready_go; // ???
assign inst_sram_we   = 4'h0;
assign inst_sram_addr  = nextpc-32'h80000000;
assign inst_sram_wdata = 32'b0;

endmodule
