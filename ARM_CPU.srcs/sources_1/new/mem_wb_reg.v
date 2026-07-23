`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name : mem_wb_reg
// Description : MEM/WB pipeline register — latches memory read data and ALU
//               result between Memory and Writeback stages.
//////////////////////////////////////////////////////////////////////////////////
module mem_wb_reg (
    input  wire        clk,
    input  wire        reset,

    // Control signals
    input  wire        reg_write_in,
    input  wire        mem_to_reg_in,

    // Data
    input  wire [7:0]  alu_result_in,
    input  wire [7:0]  mem_data_in,    // data read from SRAM
    input  wire [2:0]  rd_in,

    // Outputs
    output reg         reg_write_out,
    output reg         mem_to_reg_out,
    output reg  [7:0]  alu_result_out,
    output reg  [7:0]  mem_data_out,
    output reg  [2:0]  rd_out
);
    always @(posedge clk) begin
        if (reset) begin
            reg_write_out  <= 0;
            mem_to_reg_out <= 0;
            alu_result_out <= 8'd0;
            mem_data_out   <= 8'd0;
            rd_out         <= 3'd0;
        end else begin
            reg_write_out  <= reg_write_in;
            mem_to_reg_out <= mem_to_reg_in;
            alu_result_out <= alu_result_in;
            mem_data_out   <= mem_data_in;
            rd_out         <= rd_in;
        end
    end
endmodule
