`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name : ex_mem_reg
// Description : EX/MEM pipeline register — latches ALU result and memory
//               control signals between Execute and Memory stages.
//
// flush = 1 → insert NOP bubble (used on branch taken to kill in-flight instrs)
//////////////////////////////////////////////////////////////////////////////////
module ex_mem_reg (
    input  wire        clk,
    input  wire        reset,
    input  wire        flush,

    // Control signals
    input  wire        reg_write_in,
    input  wire        mem_read_in,
    input  wire        mem_write_in,
    input  wire        mem_to_reg_in,
    input  wire        sram_cs_in,
    input  wire        sram_oe_in,
    input  wire        sram_we_in,

    // Data
    input  wire [7:0]  alu_result_in,
    input  wire [7:0]  reg_data2_in,   // write data for STR
    input  wire [2:0]  rd_in,
    input  wire        zero_in,
    input  wire        carry_in,

    // Outputs
    output reg         reg_write_out,
    output reg         mem_read_out,
    output reg         mem_write_out,
    output reg         mem_to_reg_out,
    output reg         sram_cs_out,
    output reg         sram_oe_out,
    output reg         sram_we_out,

    output reg  [7:0]  alu_result_out,
    output reg  [7:0]  reg_data2_out,
    output reg  [2:0]  rd_out,
    output reg         zero_out,
    output reg         carry_out
);
    always @(posedge clk) begin
        if (reset || flush) begin
            reg_write_out  <= 0;
            mem_read_out   <= 0;
            mem_write_out  <= 0;
            mem_to_reg_out <= 0;
            sram_cs_out    <= 0;
            sram_oe_out    <= 0;
            sram_we_out    <= 0;
            alu_result_out <= 8'd0;
            reg_data2_out  <= 8'd0;
            rd_out         <= 3'd0;
            zero_out       <= 0;
            carry_out      <= 0;
        end else begin
            reg_write_out  <= reg_write_in;
            mem_read_out   <= mem_read_in;
            mem_write_out  <= mem_write_in;
            mem_to_reg_out <= mem_to_reg_in;
            sram_cs_out    <= sram_cs_in;
            sram_oe_out    <= sram_oe_in;
            sram_we_out    <= sram_we_in;
            alu_result_out <= alu_result_in;
            reg_data2_out  <= reg_data2_in;
            rd_out         <= rd_in;
            zero_out       <= zero_in;
            carry_out      <= carry_in;
        end
    end
endmodule
