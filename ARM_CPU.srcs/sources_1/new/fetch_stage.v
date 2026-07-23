`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name : fetch_stage
// Description : Fetch stage — PC + instruction ROM.
//               Updated for pipeline: accepts stall from hazard unit.
//////////////////////////////////////////////////////////////////////////////////
module fetch_stage (
    input  wire        clk,
    input  wire        reset,
    input  wire        stall,          // from hazard unit — freeze PC
    input  wire        branch_taken,
    input  wire [7:0]  branch_target,
    output wire [7:0]  pc_out,
    output wire [15:0] instruction
);
    wire [7:0] pc_wire;

    program_counter u_pc (
        .clk          (clk),
        .reset        (reset),
        .stall        (stall),
        .branch_taken (branch_taken),
        .branch_target(branch_target),
        .pc           (pc_wire)
    );

    instruct_mem_rom u_imem (
        .pc          (pc_wire),
        .instruction (instruction)
    );

    assign pc_out = pc_wire;
endmodule
