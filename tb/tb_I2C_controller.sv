`timescale 1ns / 1ps
// =============================================================================
// tb_I2C_controller.sv  --  simple testbench for I2C_controller
//
// What it does:
//   * 100 MHz clock + async reset
//   * runs ONE 2-byte WRITE (address 0x48, data 0xA5 then 0xC3)
//   * a tiny slave model ACKs the address and each data byte so the
//     transfer runs all the way to STOP
//
// Kept simple -- NOT modeled: clock stretching, and slave-driven READ data.
// (For a read test you'd extend the slave to drive bytes onto SDA.)
//
// NOTE: assumes the compile-blocker fixes + the loop_ctr reset from the review
// are in the DUT, otherwise the FSM never ticks and nothing moves.
// =============================================================================

module tb_I2C_controller;

    localparam int BYTES   = 2;
    localparam int DIV     = 1000;    // 100 MHz / 1000 = 100 kHz SCL
    localparam int TIMEOUT = 3000;

    // ---- DUT connections ----
    logic                sys_clk, n_rst, transmit, R_W;
    logic [6:0]          address;
    logic [8*BYTES-1:0]  data_in;
    wire  [8*BYTES-1:0]  data_out;
    wire                 sda_out, scl_out;   // DUT drives (1 = released/high)
    wire                 sda_in,  scl_in;    // bus as seen by the DUT

    // -------------------------------------------------------------------------
    // DUT
    // -------------------------------------------------------------------------
    I2C_controller #(
        .BYTES_TO_TRANSFER (BYTES),
        .CLOCK_DIVIDER     (DIV),
        .TIMEOUT           (TIMEOUT)
    ) dut (
        .sda_out (sda_out), .scl_out (scl_out), .data_out (data_out),
        .sda_in  (sda_in),  .scl_in  (scl_in),
        .transmit(transmit),.R_W     (R_W),     .n_rst   (n_rst),
        .sys_clk (sys_clk), .address (address), .data_in (data_in)
    );

    // -------------------------------------------------------------------------
    // Open-drain bus model (wired-AND): low if anyone pulls low, else high.
    // No stretching here, so SCL just mirrors the master.
    // -------------------------------------------------------------------------
    logic         bus_active = 0;     // high between START and STOP
    int  unsigned scl_falls  = 0;     // SCL falling edges since START
    wire          slave_acks = bus_active && (scl_falls != 0) && (scl_falls % 9 == 0);

    assign scl_in = scl_out;
    assign sda_in = sda_out & ~slave_acks;

    // START = SDA falls while SCL high ; STOP = SDA rises while SCL high
    always @(negedge sda_in) if (scl_in) begin bus_active = 1; scl_falls = 0; end
    always @(posedge sda_in) if (scl_in)       bus_active = 0;
    // count bits. The START's own SCL fall offsets the count so each byte's
    // 9th bit (the ACK slot) lands on a multiple of 9.
    always @(negedge scl_in) if (bus_active)   scl_falls = scl_falls + 1;

    // -------------------------------------------------------------------------
    // Clock: 10 ns period = 100 MHz
    // -------------------------------------------------------------------------
    initial sys_clk = 0;
    always #5 sys_clk = ~sys_clk;

    // -------------------------------------------------------------------------
    // Stimulus
    // -------------------------------------------------------------------------
    initial begin
        $dumpfile("tb.vcd");          // VCD viewers (Icarus/ModelSim); Vivado users ignore
        $dumpvars(0, tb_I2C_controller);

        n_rst    = 0;                 // assert reset
        transmit = 0;
        R_W      = 0;                 // 0 = write
        address  = 7'h48;
        data_out  = 16'hA5C3;          // sent MSB-first: byte 0xA5 then 0xC3

        repeat (10) @(posedge sys_clk);
        n_rst = 1;                    // release reset
        @(posedge sys_clk);

        transmit = 1;                 // kick off one transaction
        #5000;                        // hold past the first IDLE sample point
        transmit = 0;
        #500_000;                     // ~500 us: comfortably covers a 2-byte write @100 kHz
        $display("Transaction finished. data_out = %h", data_out);
        $finish;
    end

endmodule