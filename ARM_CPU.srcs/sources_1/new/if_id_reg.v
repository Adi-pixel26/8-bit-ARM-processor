`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name : if_id_reg
// Description : IF/ID pipeline register — latches instruction and PC between
//               the Fetch and Decode stages.
//
// stall = 1 → hold current values (do not update)
// flush = 1 → clear to NOP (zero out instruction, useful on branch taken)
// flush takes priority over stall.
//////////////////////////////////////////////////////////////////////////////////
module if_id_reg (
    input  wire        clk,
    input  wire        reset,
    input  wire        stall,       // 1 = freeze this register
    input  wire        flush,       // 1 = insert NOP bubble
    input  wire [7:0]  pc_in,
    input  wire [15:0] instr_in,
    output reg  [7:0]  pc_out,
    output reg  [15:0] instr_out
);
    always @(posedge clk) begin
        if (reset || flush) begin
            pc_out    <= 8'd0;
            instr_out <= 16'h0000;  // NOP
        end else if (!stall) begin
            pc_out    <= pc_in;
            instr_out <= instr_in;
        end
        // stall: hold — do nothing
    end
endmodule
