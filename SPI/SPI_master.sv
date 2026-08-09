`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06/03/2026 11:20:06 PM
// Design Name: 
// Module Name: SPI_master
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

//DATA_WIDTH >= 2
//CLK_DIVIDER >= 2 even
//n_cs is held down until bit <CS_BIT_MAX> is sent and recieved. set to DATA_WIDTH so it's held down the whole time
//setup, hold and idle cycles are measured in sys_clk cycles for higher tuneability
module SPI_master #(
parameter DATA_WIDTH = 16,
parameter CPOL = 1,
parameter CPHA = 1,
parameter CLK_DIVIDER = 6,
parameter SETUP_CYCLES = 1,
parameter HOLD_CYCLES = 0,
parameter IDLE_CYCLES = 1,
parameter CS_BIT_MAX = 13)(
output logic [DATA_WIDTH-1:0] rx_data,
output logic MOSI,
output logic n_cs,
output logic sck,
output logic tx_ready,
output logic rx_valid,
input logic [DATA_WIDTH-1:0] tx_data,
input logic transmit,
input logic MISO,
input logic sys_clk,
input logic n_rst);




function automatic int max2(input int a, input int b);
    return (a > b) ? a : b;
endfunction

logic [$clog2(CLK_DIVIDER) - 1 : 0] div_ctr;

localparam int TIMING_CTR_MAX = max2(max2(max2(SETUP_CYCLES, HOLD_CYCLES),IDLE_CYCLES),max2(CLK_DIVIDER/2, 2));
logic [$clog2(TIMING_CTR_MAX)-1:0] timing_ctr;

enum logic [2:0] {IDLE, CS_SETUP, RUNNING, CS_HOLD} state, state2;

logic [DATA_WIDTH-1:0] in_shift, out_shift;
logic [$clog2(DATA_WIDTH*2)-1:0] event_ctr;

always_ff @(posedge sys_clk or negedge n_rst) begin
    
    if (!n_rst) begin
        state2 <= IDLE;
        state <= IDLE;
        timing_ctr <= 0;
        event_ctr <= 0;
        tx_ready <= 1;
        rx_valid <= 0;
        sck <= CPOL;
        n_cs <= 1;
        MOSI <= 0;
        div_ctr <= 0;
    end
    else begin
        if ((div_ctr == CLK_DIVIDER/2 -1) || (state2!=RUNNING)) begin
            div_ctr <= 0;
            case(state)
                IDLE: begin
                    if(transmit && (timing_ctr == (max2(IDLE_CYCLES,1) - 1))) begin
                        if (SETUP_CYCLES == 0) begin
                            state <= RUNNING;
                            MOSI <= tx_data[DATA_WIDTH-1];
                        end
                        else
                            state <= CS_SETUP;

                        timing_ctr <= 0;
                        event_ctr <= 0;
                        if(tx_ready) begin
                            out_shift <= tx_data;
                            MOSI <= tx_data[DATA_WIDTH-1];
                            tx_ready <= 0;
                        end
                    end
                    else if (timing_ctr != (max2(IDLE_CYCLES,1) - 1))
                        timing_ctr <= timing_ctr+1;
                    sck <= CPOL;
                    n_cs <= 1;
                end
                CS_SETUP: begin
                    if(timing_ctr == (max2(SETUP_CYCLES,1) - 1)) begin
                        state <= RUNNING;
                        timing_ctr <= 0;
                        event_ctr <= 0;
                        MOSI <= out_shift[DATA_WIDTH-1];
                    end
                    else
                        timing_ctr <= timing_ctr+1;
                    sck <= CPOL;
                    n_cs <= 0;
                end
                RUNNING: begin
                    
                    sck <= !sck; 
                    if (event_ctr[0] == CPHA) begin //sample
                        in_shift <= {in_shift[DATA_WIDTH-2:0], MISO};
                        if(event_ctr == DATA_WIDTH*2-1) begin
                            if (transmit) begin
                                if(HOLD_CYCLES == 0)
                                    if(IDLE_CYCLES == 0)
                                        if(SETUP_CYCLES == 0)
                                            state <= RUNNING;
                                        else
                                            state <= CS_SETUP;  
                                    else 
                                        state <= IDLE;
                                else
                                    state <= CS_HOLD;
                                out_shift <= tx_data;
                                tx_ready<=0;
                            end
                            else begin
                                if (HOLD_CYCLES == 0)
                                    state <= IDLE;
                                else
                                    state <= CS_HOLD;
                                timing_ctr <= 0; 
                            end
                            rx_data <= {in_shift[DATA_WIDTH-2:0], MISO};
                            rx_valid <= 1;        
                            
                            event_ctr <= 0;
                        end
                        else
                            event_ctr <= event_ctr + 1;            
                    end
                    else begin //shift
                        
                        if (event_ctr != 0) begin
                            MOSI <= out_shift[DATA_WIDTH-2];
                            out_shift  <= {out_shift[DATA_WIDTH-2:0], 1'b0};
                        end
                        else
                            MOSI <= out_shift[DATA_WIDTH-1];
                        if(event_ctr == DATA_WIDTH*2-1) begin
                            if (transmit) begin
                                if(HOLD_CYCLES == 0)
                                    if(IDLE_CYCLES == 0)
                                        if(SETUP_CYCLES == 0)
                                            state <= RUNNING;
                                        else
                                            state <= CS_SETUP;             
                                    else 
                                        state <= IDLE;
                                else
                                    state <= CS_HOLD;
                                out_shift <= tx_data;
                                MOSI <= tx_data[DATA_WIDTH-1];
                                tx_ready<=0;
                            end
                            else begin
                                if (HOLD_CYCLES == 0)
                                    state <= IDLE;
                                else
                                    state <= CS_HOLD;
                                timing_ctr <= 0; 
                            end
                            rx_data <= in_shift;
                            rx_valid <= 1;
                            event_ctr <= 0;
                        end
                        else
                            event_ctr <= event_ctr + 1;
                    end
                    if (event_ctr == DATA_WIDTH*2-3)
                        tx_ready <= 1;
                    if (event_ctr == 1)
                        rx_valid <= 0;
                    if (event_ctr > (CS_BIT_MAX*2))
                        n_cs <= 1;
                    else
                        n_cs <= 0;

                end
                CS_HOLD: begin
                    if(timing_ctr == (max2(HOLD_CYCLES,1) - 1)) begin

                        if (transmit) begin
                            if(IDLE_CYCLES == 0)
                                if(SETUP_CYCLES == 0)
                                    state <= RUNNING;
                                else 
                                    state <= CS_SETUP;
                            else
                                state <= IDLE;
                            if(tx_ready) begin
                                out_shift <= tx_data;
                                MOSI <= tx_data[DATA_WIDTH-1];
                                tx_ready<=0;
                            end
                        end
                        timing_ctr <= 0;
                    end
                    else
                        timing_ctr <= timing_ctr+1;
                    sck <= CPOL;
                    n_cs <= 0;
                end
                
            endcase
            state2 <= state;
        end
        else
            div_ctr <= div_ctr+1;
    end
end

endmodule