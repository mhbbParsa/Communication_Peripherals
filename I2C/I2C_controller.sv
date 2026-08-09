`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06/06/2026 05:17:52 PM
// Design Name: 
// Module Name: I2C_controller
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

//scl_out and sda_out must be wired open drain on top module
module I2C_controller
#(parameter BYTES_TO_TRANSFER=2,
parameter CLOCK_DIVIDER=1000,
parameter TIMEOUT=3000)(
output logic sda_out,
output logic scl_out,
output logic [8*BYTES_TO_TRANSFER-1:0] data_in,
input logic [8*BYTES_TO_TRANSFER-1:0] data_out,
input logic sda_in,
input logic scl_in,
input logic transmit,
input logic R_W,
input logic n_rst,
input logic sys_clk,
input logic [6:0] address);


enum logic [4:0] {START, STOP, IDLE, ADDRESS, READ_WRITE, WRITE_ACK, READ, WRITE, READ_ACK} state;
enum logic [4:0] {DATA, CLK_RISING, MID_SCL_HIGH, CLK_FALLING} sub_state;
enum logic [1:0] {QUARTER, HALF, ALL} loop_condition;

logic [$clog2(CLOCK_DIVIDER/2)-1:0] loop_ctr;
logic [3:0] bit_ctr;
logic [$clog2(BYTES_TO_TRANSFER):0] byte_ctr;
logic [6:0] address_shift;
logic ack;
logic R_W_reg;
logic [8*BYTES_TO_TRANSFER-1:0] out_shift;
logic [8*BYTES_TO_TRANSFER-1:0]  in_shift;
logic [$clog2(TIMEOUT)-1:0] timeout_ctr;


logic sda_in2, sda_in3;
logic scl_in2, scl_in3;
logic R_W2   , R_W3;
always_ff @(posedge sys_clk or negedge n_rst) begin
    if(!n_rst) begin
        sda_in3 <= 1;
        sda_in2 <= 1;
        scl_in3 <= 1;
        scl_in2 <= 1;
    end
    else begin
        sda_in3 <= sda_in2;
        sda_in2 <= sda_in;
        scl_in3 <= scl_in2;
        scl_in2 <= scl_in;
    end
end


always_ff @(posedge sys_clk or negedge n_rst) begin
    if(!n_rst) begin
        state <= IDLE;
        timeout_ctr <= 0;
        loop_ctr <= 0;
        sda_out <= 1;
        scl_out <= 1;
        loop_condition <= ALL;
    end
    else if (!scl_in3 && scl_out && (state != STOP) && (state != IDLE)) begin
        timeout_ctr <= timeout_ctr + 1;
        if (timeout_ctr == TIMEOUT) begin
            state <= STOP;
            sub_state <= DATA;
        end
    end
    else if (((loop_ctr == CLOCK_DIVIDER/4 - 1) && (loop_condition == QUARTER)) || ((loop_ctr == CLOCK_DIVIDER/2 - 1) && (loop_condition == HALF)) || ((loop_ctr == 0) && (loop_condition == ALL))) begin
        case(state)
            IDLE: begin
                if(transmit) begin
                    state <= START;
                    loop_condition <= QUARTER;
                    sda_out <= 0;
                    out_shift <= data_out;
                    R_W_reg <= R_W;
                    address_shift <= address;
                    
                end
            end
            START: begin
                state <= ADDRESS;
                loop_condition <= QUARTER;
                scl_out <= 0;
                bit_ctr <= 0;
                sub_state <= DATA;
            end
            ADDRESS: begin
                case(sub_state)
                    DATA: begin
                        sda_out <= address_shift[6];
                        address_shift <= {address_shift[5:0], 1'b0};
                        
                        loop_condition <= QUARTER;
                        sub_state <= CLK_RISING;
                    end
                    CLK_RISING: begin
                        
                        loop_condition <= HALF;
                        sub_state <= CLK_FALLING;
                        scl_out <= 1;
                    end
                    CLK_FALLING: begin
                        
                        loop_condition <= QUARTER;
                        sub_state <= DATA;
                        scl_out <= 0;
                        if(bit_ctr == (7 - 1))
                            state <= READ_WRITE;
                        bit_ctr <= bit_ctr + 1;
                    end
                endcase
            end
            READ_WRITE: begin
                case(sub_state)
                    DATA: begin
                        sda_out <= R_W_reg;
                        
                        loop_condition <= QUARTER;
                        sub_state <= CLK_RISING;
                    end
                    CLK_RISING: begin
                        
                        loop_condition <= HALF;
                        sub_state <= CLK_FALLING;
                        scl_out <= 1;
                    end
                    CLK_FALLING: begin
                        
                        loop_condition <= QUARTER;
                        sub_state <= DATA;
                        scl_out <= 0;
                        state <= READ_ACK;
                        byte_ctr <= 0;
                        bit_ctr <= 0;
                    end
                endcase  
            end
            READ_ACK: begin
                case(sub_state)
                    DATA: begin
                        sda_out <= 1;
                        
                        loop_condition <= QUARTER;
                        sub_state <= CLK_RISING;
                    end
                    CLK_RISING: begin
                        
                        loop_condition <= QUARTER;
                        sub_state <= MID_SCL_HIGH;
                        scl_out <= 1;
                    end
                    MID_SCL_HIGH: begin
                        
                        loop_condition <= QUARTER;
                        sub_state <= CLK_FALLING;
                        ack <= sda_in3;

                    end
                    CLK_FALLING: begin
                        
                        loop_condition <= QUARTER;
                        sub_state <= DATA;
                        scl_out <= 0;
                        if(ack || (byte_ctr == BYTES_TO_TRANSFER))
                            state <= STOP;
                        else begin
                            bit_ctr <= 0;
                            if(R_W_reg)
                                    state <= READ;
                                else
                                    state <= WRITE;
                        end
                    end
                endcase
            end
        
            WRITE: begin
                case(sub_state)
                    DATA: begin
                        sda_out <= out_shift[8*BYTES_TO_TRANSFER-1];
                        out_shift <= {out_shift[8*BYTES_TO_TRANSFER-2:0], 1'b0};
                        
                        
                        loop_condition <= QUARTER;
                        sub_state <= CLK_RISING;
                    end
                    CLK_RISING: begin
                        
                        loop_condition <= HALF;
                        sub_state <= CLK_FALLING;
                        scl_out <= 1;
                    end
                    CLK_FALLING: begin
                        
                        loop_condition <= QUARTER;
                        sub_state <= DATA;
                        scl_out <= 0;
                        if(bit_ctr == (8 - 1)) begin
                            byte_ctr <= byte_ctr + 1;
                            state <= READ_ACK;
                        end
                        bit_ctr <= bit_ctr + 1;
                    end
                endcase
            end
            READ: begin
                case(sub_state)
                    DATA: begin
                        sda_out <= 1;
                        loop_condition <= QUARTER;
                        sub_state <= CLK_RISING;
                    end
                    CLK_RISING: begin
                        
                        loop_condition <= HALF;
                        sub_state <= MID_SCL_HIGH;
                        scl_out <= 1;
                    end
                    MID_SCL_HIGH: begin
                        in_shift <= {in_shift[8*BYTES_TO_TRANSFER-2:0], sda_in3};                       
                        loop_condition <= QUARTER;
                        sub_state <= CLK_FALLING;
                    end
                    CLK_FALLING: begin
                        
                        loop_condition <= QUARTER;
                        scl_out <= 0;
                        
                        if(bit_ctr == (8 - 1)) begin
                            byte_ctr <= byte_ctr + 1;
                            state <= WRITE_ACK;
                            sub_state <= DATA;
                        end
                        else
                            sub_state <= CLK_RISING;
                        bit_ctr <= bit_ctr + 1;
                    end
                endcase
            end
            WRITE_ACK: begin
                case(sub_state)
                    DATA: begin
                        if(byte_ctr == (BYTES_TO_TRANSFER - 1))
                            sda_out <= 1;
                        else
                            sda_out <= 0;
                        
                        loop_condition <= QUARTER;
                        sub_state <= CLK_RISING;
                    end
                    CLK_RISING: begin
                        
                        loop_condition <= HALF;
                        sub_state <= CLK_FALLING;
                        scl_out <= 1;
                    end
                    CLK_FALLING: begin
                        
                        loop_condition <= QUARTER;
                        sub_state <= DATA;
                        scl_out <= 0;
                        if(byte_ctr == BYTES_TO_TRANSFER )
                            state <= STOP;
                        else begin
                            bit_ctr <= 0;
                            if(R_W_reg)
                                state <= READ;
                            else
                                state <= WRITE;
                        end
                    end
                endcase
            end
            STOP: begin
                case(sub_state)
                    DATA: begin
                        data_in <= in_shift;
                        sda_out <= 0;
                        loop_condition <= HALF;
                        sub_state <= MID_SCL_HIGH;
                    end
                    MID_SCL_HIGH: begin
                        scl_out <= 1;
                        sub_state <= CLK_FALLING;
                        loop_condition <= QUARTER;
                    end
                    CLK_FALLING: begin
                        
                        loop_condition <= QUARTER;
                        sda_out <= 1;
                        sub_state <= DATA;
                        state <= IDLE;
                        loop_condition <= ALL;
                    end
                endcase
            end
        endcase
        loop_ctr <= 0;
        timeout_ctr <= 0;
    end
    else
        loop_ctr <= loop_ctr + 1;
end










endmodule
