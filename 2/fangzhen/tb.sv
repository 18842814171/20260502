`timescale 1ns / 1ps
module tb;

wire clk_50M, clk_11M0592;
assign clk_11M0592 = 1'b0;

reg clock_btn = 0;         //BTN5ÊÖ¶¯Ê±ÖÓ°´Å¥¿ª¹Ø£¬´øÏû¶¶µçÂ·£¬°´ÏÂÊ±Îª1
reg reset_btn = 0;         //BTN6ÊÖ¶¯¸´Î»°´Å¥¿ª¹Ø£¬´øÏû¶¶µçÂ·£¬°´ÏÂÊ±Îª1

reg[31:0] dip_sw;     //32Î»²¦Âë¿ª¹Ø£¬²¦µ½"ON"Ê±Îª1

wire[15:0] leds;       //16Î»LED£¬Êä³öÊ±1µãÁÁ
wire[7:0]  dpy0;       //ÊýÂë¹ÜµÍÎ»ÐÅºÅ£¬°üÀ¨Ð¡Êýµã£¬Êä³ö1µãÁÁ
wire[7:0]  dpy1;       //ÊýÂë¹Ü¸ßÎ»ÐÅºÅ£¬°üÀ¨Ð¡Êýµã£¬Êä³ö1µãÁÁ

wire txd;  //Ö±Á¬´®¿Ú·¢ËÍ¶Ë
wire rxd;  //Ö±Á¬´®¿Ú½ÓÊÕ¶Ë
wire tb_uart_txd;
wire tb_uart_busy;
reg  tb_uart_start = 1'b0;
reg  [7:0] tb_uart_data = 8'h00;
reg  tb_sent_T = 1'b0;
integer fib_match_idx = 0;

wire[31:0] base_ram_data; //BaseRAMÊý¾Ý£¬µÍ8Î»ÓëCPLD´®¿Ú¿ØÖÆÆ÷¹²Ïí
wire[19:0] base_ram_addr; //BaseRAMµØÖ·
wire[3:0] base_ram_be_n;  //BaseRAM×Ö½ÚÊ¹ÄÜ£¬µÍÓÐÐ§¡£Èç¹û²»Ê¹ÓÃ×Ö½ÚÊ¹ÄÜ£¬Çë±£³ÖÎª0
wire base_ram_ce_n;       //BaseRAMÆ¬Ñ¡£¬µÍÓÐÐ§
wire base_ram_oe_n;       //BaseRAM¶ÁÊ¹ÄÜ£¬µÍÓÐÐ§
wire base_ram_we_n;       //BaseRAMÐ´Ê¹ÄÜ£¬µÍÓÐÐ§

wire[31:0] ext_ram_data; //ExtRAMÊý¾Ý
wire[19:0] ext_ram_addr; //ExtRAMµØÖ·
wire[3:0] ext_ram_be_n;  //ExtRAM×Ö½ÚÊ¹ÄÜ£¬µÍÓÐÐ§¡£Èç¹û²»Ê¹ÓÃ×Ö½ÚÊ¹ÄÜ£¬Çë±£³ÖÎª0
wire ext_ram_ce_n;       //ExtRAMÆ¬Ñ¡£¬µÍÓÐÐ§
wire ext_ram_oe_n;       //ExtRAM¶ÁÊ¹ÄÜ£¬µÍÓÐÐ§
wire ext_ram_we_n;       //ExtRAMÐ´Ê¹ÄÜ£¬µÍÓÐÐ§

//WindowsÐèÒª×¢ÒâÂ·¾¶·Ö¸ô·ûµÄ×ªÒå£¬ÀýÈç"D:\\foo\\bar.bin"
parameter BASE_RAM_INIT_FILE = "E:\fangzhen\\lab2\\lab2.bin"; //BaseRAM³õÊ¼»¯ÎÄ¼þ£¬ÇëÐÞ¸ÄÎªÊµ¼ÊµÄ¾ø¶ÔÂ·¾¶
parameter EXT_RAM_INIT_FILE = "E:\fangzhen\\lab2\\lab2.bin";    //ExtRAM³õÊ¼»¯ÎÄ¼þ£¬ÇëÐÞ¸ÄÎªÊµ¼ÊµÄ¾ø¶ÔÂ·¾¶
//parameter FLASH_INIT_FILE = "/tmp/kernel.elf";    //Flash³õÊ¼»¯ÎÄ¼þ£¬ÇëÐÞ¸ÄÎªÊµ¼ÊµÄ¾ø¶ÔÂ·¾¶

assign rxd = tb_uart_txd; // driven by TB UART transmitter

initial begin 
    //ÔÚÕâÀï¿ÉÒÔ×Ô¶¨Òå²âÊÔÊäÈëÐòÁÐ£¬ÀýÈç£º
    clk = 1'b0;
    reset_btn = 1;
    #2000;
    reset_btn = 0;
    

 /*   for (integer i = 0; i < 20; i = i+1) begin
        #100; //µÈ´ý100ns
        clock_btn = 1; //°´ÏÂÊÖ¹¤Ê±ÖÓ°´Å¥
        #100; //µÈ´ý100ns
        clock_btn = 0; //ËÉ¿ªÊÖ¹¤Ê±ÖÓ°´Å¥
    end*/
end
reg clk;
always #10 clk=~clk;

// TB UART transmitter: send character to DUT RX (rxd)
async_transmitter #(
    .ClkFrequency(50000000),
    .Baud(9600)
) tb_uart_tx (
    .rst      (reset_btn),
    .clk      (clk),
    .TxD_start(tb_uart_start),
    .TxD_data (tb_uart_data),
    .TxD      (tb_uart_txd),
    .TxD_busy (tb_uart_busy)
);
// ´ý²âÊÔÓÃ»§Éè¼Æ
thinpad_top dut(
    .clk_50M(clk),
    .clk_11M0592(clk_11M0592),
    .clock_btn(clock_btn),
    .reset_btn(reset_btn),
    .txd(txd),
    .rxd(rxd),
    .base_ram_data(base_ram_data),
    .base_ram_addr(base_ram_addr),
    .base_ram_ce_n(base_ram_ce_n),
    .base_ram_oe_n(base_ram_oe_n),
    .base_ram_we_n(base_ram_we_n),
    .base_ram_be_n(base_ram_be_n),
    .ext_ram_data(ext_ram_data),
    .ext_ram_addr(ext_ram_addr),
    .ext_ram_ce_n(ext_ram_ce_n),
    .ext_ram_oe_n(ext_ram_oe_n),
    .ext_ram_we_n(ext_ram_we_n),
    .ext_ram_be_n(ext_ram_be_n)
);
// Ê±ÖÓÔ´
/*clock osc(
    .clk_11M0592(clk_11M0592),
    .clk_50M    (clk_50M)
);
*/
// BaseRAM ·ÂÕæÄ£ÐÍ
sram_model base1(/*autoinst*/
            .DataIO(base_ram_data[15:0]),
            .Address(base_ram_addr[19:0]),
            .OE_n(base_ram_oe_n),
            .CE_n(base_ram_ce_n),
            .WE_n(base_ram_we_n),
            .LB_n(base_ram_be_n[0]),
            .UB_n(base_ram_be_n[1]));
sram_model base2(/*autoinst*/
            .DataIO(base_ram_data[31:16]),
            .Address(base_ram_addr[19:0]),
            .OE_n(base_ram_oe_n),
            .CE_n(base_ram_ce_n),
            .WE_n(base_ram_we_n),
            .LB_n(base_ram_be_n[2]),
            .UB_n(base_ram_be_n[3]));
// ExtRAM ·ÂÕæÄ£ÐÍ
sram_model ext1(/*autoinst*/
            .DataIO(ext_ram_data[15:0]),
            .Address(ext_ram_addr[19:0]),
            .OE_n(ext_ram_oe_n),
            .CE_n(ext_ram_ce_n),
            .WE_n(ext_ram_we_n),
            .LB_n(ext_ram_be_n[0]),
            .UB_n(ext_ram_be_n[1]));
sram_model ext2(/*autoinst*/
            .DataIO(ext_ram_data[31:16]),
            .Address(ext_ram_addr[19:0]),
            .OE_n(ext_ram_oe_n),
            .CE_n(ext_ram_ce_n),
            .WE_n(ext_ram_we_n),
            .LB_n(ext_ram_be_n[2]),
            .UB_n(ext_ram_be_n[3]));
// Flash ·ÂÕæÄ£ÐÍ
//x28fxxxp30 #(.FILENAME_MEM(FLASH_INIT_FILE)) flash(
//    .A(flash_a[1+:22]), 
//    .DQ(flash_d), 
//    .W_N(flash_we_n),    // Write Enable 
//    .G_N(flash_oe_n),    // Output Enable
//    .E_N(flash_ce_n),    // Chip Enable
//    .L_N(1'b0),    // Latch Enable
//    .K(1'b0),      // Clock
//    .WP_N(flash_vpen),   // Write Protect
//    .RP_N(flash_rp_n),   // Reset/Power-Down
//    .VDD('d3300), 
//    .VDDQ('d3300), 
//    .VPP('d1800), 
//    .Info(1'b1));

//initial begin 
//    wait(flash_byte_n == 1'b0);
//    $display("8-bit Flash interface is not supported in simulation!");
//    $display("Please tie flash_byte_n to high");
//    $stop;
//end

// ´ÓÎÄ¼þ¼ÓÔØ BaseRAM
initial begin 
    reg [31:0] tmp_array[0:1048575];
    integer n_File_ID, n_Init_Size;
    n_File_ID = $fopen(BASE_RAM_INIT_FILE, "rb");
    if(!n_File_ID)begin 
        n_Init_Size = 0;
        $display("Failed to open BaseRAM init file");
    end else begin
        n_Init_Size = $fread(tmp_array, n_File_ID);
        n_Init_Size /= 4;
        $fclose(n_File_ID);
    end
    $display("BaseRAM Init Size(words): %d",n_Init_Size);
    for (integer i = 0; i < n_Init_Size; i++) begin
        base1.mem_array0[i] = tmp_array[i][24+:8];
        base1.mem_array1[i] = tmp_array[i][16+:8];
        base2.mem_array0[i] = tmp_array[i][8+:8];
        base2.mem_array1[i] = tmp_array[i][0+:8];
    end
end

// ´ÓÎÄ¼þ¼ÓÔØ ExtRAM
//initial begin 
//    reg [31:0] tmp_array[0:1048575];
//    integer n_File_ID, n_Init_Size;
//    n_File_ID = $fopen(EXT_RAM_INIT_FILE, "rb");
//    if(!n_File_ID)begin 
//        n_Init_Size = 0;
//        $display("Failed to open ExtRAM init file");
//    end else begin
//        n_Init_Size = $fread(tmp_array, n_File_ID);
//        n_Init_Size /= 4;
//        $fclose(n_File_ID);
//    end
//    $display("ExtRAM Init Size(words): %d",n_Init_Size);
//    for (integer i = 0; i < n_Init_Size; i++) begin
//        ext1.mem_array0[i] = tmp_array[i][24+:8];
//        ext1.mem_array1[i] = tmp_array[i][16+:8];
//        ext2.mem_array0[i] = tmp_array[i][8+:8];
//        ext2.mem_array1[i] = tmp_array[i][0+:8];
//    end
//end
always @(posedge clk) begin
    reg [31:0] ext_word_actual;
    reg [19:0] wr_addr;
    reg [3:0]  wr_be_n;
    reg [31:0] wr_bus_data;
    if (~ext_ram_ce_n && ~ext_ram_we_n) begin
        // Delay one simulation step so SRAM model has updated memory arrays.
        wr_addr     = ext_ram_addr;
        wr_be_n     = ext_ram_be_n;
        wr_bus_data = ext_ram_data;
        #1;
        ext_word_actual = {
            ext1.mem_array0[wr_addr],
            ext1.mem_array1[wr_addr],
            ext2.mem_array0[wr_addr],
            ext2.mem_array1[wr_addr]
        };
        $display("EXT_WR byte_addr=%08h be_n=%b bus_wdata=%08h",
                 {wr_addr, 2'b00}, wr_be_n, wr_bus_data);
    end
end

// UART monitor: print a char whenever CPU writes UART TX register (0x...3f8).
always @(posedge clk) begin
    reg [7:0] tx_byte;
    tb_uart_start <= 1'b0;
    if (dut.data_access_uart && dut.uart_data_addr_hit && dut.data_sram_we_any) begin
        // Derive TX byte from store bus to avoid Z/XX from combinational helpers.
        if (dut.data_sram_wen[0])      tx_byte = dut.data_sram_wdata[7:0];
        else if (dut.data_sram_wen[1]) tx_byte = dut.data_sram_wdata[15:8];
        else if (dut.data_sram_wen[2]) tx_byte = dut.data_sram_wdata[23:16];
        else if (dut.data_sram_wen[3]) tx_byte = dut.data_sram_wdata[31:24];
        else                           tx_byte = 8'h00;
        $write("%c", tx_byte);

        // Detect "Fib Finish." then send one 'T' (0x54) back to DUT.
        if (!tb_sent_T) begin
            case (fib_match_idx)
                0: fib_match_idx <= (tx_byte == "F") ? 1 : 0;
                1: fib_match_idx <= (tx_byte == "i") ? 2 : ((tx_byte == "F") ? 1 : 0);
                2: fib_match_idx <= (tx_byte == "b") ? 3 : ((tx_byte == "F") ? 1 : 0);
                3: fib_match_idx <= (tx_byte == " ") ? 4 : ((tx_byte == "F") ? 1 : 0);
                4: fib_match_idx <= (tx_byte == "F") ? 5 : 0;
                5: fib_match_idx <= (tx_byte == "i") ? 6 : ((tx_byte == "F") ? 1 : 0);
                6: fib_match_idx <= (tx_byte == "n") ? 7 : ((tx_byte == "F") ? 1 : 0);
                7: fib_match_idx <= (tx_byte == "i") ? 8 : ((tx_byte == "F") ? 1 : 0);
                8: fib_match_idx <= (tx_byte == "s") ? 9 : ((tx_byte == "F") ? 1 : 0);
                9: fib_match_idx <= (tx_byte == "h") ? 10 : ((tx_byte == "F") ? 1 : 0);
                10: begin
                    if (tx_byte == ".") begin
                        fib_match_idx <= 0;
                        tb_uart_data <= "T";
                        if (!tb_uart_busy) begin
                            tb_uart_start <= 1'b1;
                            tb_sent_T <= 1'b1;
                            $display("\nTB_UART: sent 'T' to DUT");
                        end
                    end else begin
                        fib_match_idx <= (tx_byte == "F") ? 1 : 0;
                    end
                end
                default: fib_match_idx <= 0;
            endcase
        end
    end
end
endmodule
