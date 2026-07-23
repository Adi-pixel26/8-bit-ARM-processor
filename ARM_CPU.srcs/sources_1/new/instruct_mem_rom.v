`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name : instruct_mem_rom
// Description : 256-entry x 16-bit instruction ROM
//               Testbench writes directly to mem[] during reset.
//               No internal initial block — avoids race conditions.
//
// Instruction Format (16-bit):
//   [15:12] opcode
//   [11:9]  rd
//   [8:6]   rs1
//   [5:3]   rs2
//   [2:0]   imm3
//////////////////////////////////////////////////////////////////////////////////
module instruct_mem_rom (
    input  wire [7:0]  pc,
    output wire [15:0] instruction
);
    reg [15:0] mem [0:255];

    // Initialise all slots to NOP (zero) so uninitialised entries
    // never produce X on the instruction bus
    integer i;
    initial begin
        for (i = 0; i < 256; i = i + 1)
            mem[i] = 16'h0000;
    end

    assign instruction = mem[pc];
endmodule
