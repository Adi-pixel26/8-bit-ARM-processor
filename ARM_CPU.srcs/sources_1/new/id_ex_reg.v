`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name : id_ex_reg
// Description : ID/EX pipeline register — latches decoded control signals and
//               register data between Decode and Execute stages.
//
// stall = 1 → hold current values
// flush = 1 → insert NOP bubble (zero all control signals)
//////////////////////////////////////////////////////////////////////////////////
module id_ex_reg (
    input  wire        clk,
    input  wire        reset,
    input  wire        stall,
    input  wire        flush,

    // Control signals from decode
    input  wire        reg_write_in,
    input  wire        mem_read_in,
    input  wire        mem_write_in,
    input  wire        mem_to_reg_in,
    input  wire        alu_src_in,
    input  wire [2:0]  alu_op_in,
    input  wire        branch_in,
    input  wire        inv_a_in,
    input  wire        sram_cs_in,
    input  wire        sram_oe_in,
    input  wire        sram_we_in,

    // Data from decode
    input  wire [7:0]  pc_in,
    input  wire [7:0]  reg_data1_in,
    input  wire [7:0]  reg_data2_in,
    input  wire [2:0]  rd_in,
    input  wire [2:0]  rs1_in,
    input  wire [2:0]  rs2_in,
    input  wire [2:0]  imm3_in,

    // Outputs
    output reg         reg_write_out,
    output reg         mem_read_out,
    output reg         mem_write_out,
    output reg         mem_to_reg_out,
    output reg         alu_src_out,
    output reg  [2:0]  alu_op_out,
    output reg         branch_out,
    output reg         inv_a_out,
    output reg         sram_cs_out,
    output reg         sram_oe_out,
    output reg         sram_we_out,

    output reg  [7:0]  pc_out,
    output reg  [7:0]  reg_data1_out,
    output reg  [7:0]  reg_data2_out,
    output reg  [2:0]  rd_out,
    output reg  [2:0]  rs1_out,
    output reg  [2:0]  rs2_out,
    output reg  [2:0]  imm3_out
);
    always @(posedge clk) begin
        if (reset || flush) begin
            // Insert NOP — zero all control signals
            reg_write_out  <= 0;
            mem_read_out   <= 0;
            mem_write_out  <= 0;
            mem_to_reg_out <= 0;
            alu_src_out    <= 0;
            alu_op_out     <= 3'b000;
            branch_out     <= 0;
            inv_a_out      <= 0;
            sram_cs_out    <= 0;
            sram_oe_out    <= 0;
            sram_we_out    <= 0;
            pc_out         <= 8'd0;
            reg_data1_out  <= 8'd0;
            reg_data2_out  <= 8'd0;
            rd_out         <= 3'd0;
            rs1_out        <= 3'd0;
            rs2_out        <= 3'd0;
            imm3_out       <= 3'd0;
        end else if (!stall) begin
            reg_write_out  <= reg_write_in;
            mem_read_out   <= mem_read_in;
            mem_write_out  <= mem_write_in;
            mem_to_reg_out <= mem_to_reg_in;
            alu_src_out    <= alu_src_in;
            alu_op_out     <= alu_op_in;
            branch_out     <= branch_in;
            inv_a_out      <= inv_a_in;
            sram_cs_out    <= sram_cs_in;
            sram_oe_out    <= sram_oe_in;
            sram_we_out    <= sram_we_in;
            pc_out         <= pc_in;
            reg_data1_out  <= reg_data1_in;
            reg_data2_out  <= reg_data2_in;
            rd_out         <= rd_in;
            rs1_out        <= rs1_in;
            rs2_out        <= rs2_in;
            imm3_out       <= imm3_in;
        end
    end
endmodule
