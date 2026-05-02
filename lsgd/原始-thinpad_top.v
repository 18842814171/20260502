//`default_nettype none

module thinpad_top(
    input wire clk_50M,           //50MHz 时钟输入
    input wire clk_11M0592,       //11.0592MHz 时钟输入（备用，可不用）

    input wire clock_btn,         //BTN5手动时钟按钮开关，带消抖电路，按下时为1
    input wire reset_btn,         //BTN6手动复位按钮开关，带消抖电路，按下时为1

    //BaseRAM信号
    inout wire[31:0] base_ram_data,  //BaseRAM数据，低8位与CPLD串口控制器共享
    output wire[19:0] base_ram_addr, //BaseRAM地址
    output wire[3:0] base_ram_be_n,  //BaseRAM字节使能，低有效。如果不使用字节使能，请保持为0
    output wire base_ram_ce_n,       //BaseRAM片选，低有效
    output wire base_ram_oe_n,       //BaseRAM读使能，低有效
    output wire base_ram_we_n,       //BaseRAM写使能，低有效

    //ExtRAM信号
    inout wire[31:0] ext_ram_data,  //ExtRAM数据
    output wire[19:0] ext_ram_addr, //ExtRAM地址
    output wire[3:0] ext_ram_be_n,  //ExtRAM字节使能，低有效。如果不使用字节使能，请保持为0
    output wire ext_ram_ce_n,       //ExtRAM片选，低有效
    output wire ext_ram_oe_n,       //ExtRAM读使能，低有效
    output wire ext_ram_we_n,       //ExtRAM写使能，低有效

    //直连串口信号
    output wire txd,  //直连串口发送端
    input  wire rxd   //直连串口接收端
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

//cpu
mycpu_top cpu(
    .clk              (clk_50M   ),
    .resetn           (reset_btn),  //low active

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
assign base_ram_addr = inst_sram_addr[21:2] ;
assign base_ram_be_n = 4'h0;
assign base_ram_ce_n = (inst_sram_en===1)?1'b0:1'b1; 
assign base_ram_oe_n = 1'b0; 
assign base_ram_we_n = 1'b1;   

//assign ext_ram_data = (data_sram_wen[0]===1)?data_sram_wdata : 32'bz;
assign ext_ram_data = ~ext_ram_we_n ? data_sram_wdata : 32'bz;
assign data_sram_rdata = ext_ram_data;
assign ext_ram_addr  = data_sram_addr[21:2] ;     

assign ext_ram_be_n = ~data_sram_wen;
assign ext_ram_ce_n = 1'b0;        
assign ext_ram_oe_n = 1'b0;  
assign ext_ram_we_n = ~(&data_sram_wen); 

    
endmodule
