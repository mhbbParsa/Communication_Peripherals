`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06/04/2026 04:18:06 PM
// Design Name: 
// Module Name: SPI_master_tb
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module SPI_master_tb;

// DUT signals
logic [15:0] rx_data;
logic       MOSI, n_cs, sck;
logic [15:0] tx_data;
logic       MISO, sys_clk, n_rst, tx_ready, rx_valid, transmit;

// Instantiate DUT
SPI_master dut (
    .rx_data  (rx_data),
    .MOSI     (MOSI),
    .n_cs     (n_cs),
    .sck      (sck),
    .tx_ready   (tx_ready),
    .rx_valid   (rx_valid),
    .tx_data    (tx_data),
    .transmit (transmit),
    .MISO     (MISO),
    .sys_clk      (sys_clk),
    .n_rst  (n_rst)
);

// 10ns clock
initial sys_clk = 0;
always #5 sys_clk = ~sys_clk;

initial begin
    #3
    forever #5 MISO <= $random % 2;
end

initial begin
    #3
    forever #5 tx_data <= $random % (256*256);
end

initial begin
n_rst=1;
#20
n_rst=0;
#6
n_rst=1;
#22

transmit=1;
//#280
//transmit=0;
end



endmodule