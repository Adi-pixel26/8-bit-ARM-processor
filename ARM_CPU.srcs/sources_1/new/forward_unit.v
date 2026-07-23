`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name : forward_unit
// Description : Detects RAW hazards that CAN be resolved by forwarding
//               (bypassing the register file) and generates mux select signals.
//
// Two forwarding paths:
//
//   EX forwarding  (forward_a/b = 2'b10):
//     The instruction now in MEM has a result we need in EX.
//     Route EX/MEM.alu_result → ALU input A or B.
//     Covers back-to-back dependent instructions:
//       ADD R3, R1, R2    ← now in MEM, result = R3
//       SUB R4, R3, R2    ← now in EX, needs R3
//
//   MEM forwarding (forward_a/b = 2'b01):
//     The instruction now in WB has a result we need in EX.
//     Route MEM/WB.wb_data → ALU input A or B.
//     Covers instructions with one instruction in between:
//       ADD R3, R1, R2    ← now in WB
//       NOP               ← was in MEM
//       SUB R4, R3, R2    ← now in EX, needs R3
//
//   No forwarding (forward_a/b = 2'b00):
//     Use the register file value latched in ID/EX normally.
//
// EX forwarding takes priority over MEM forwarding when both match
// (which happens when the same register is written by two back-to-back
// instructions — the most recent write should win).
//
// R0 is hardwired to 0 — never forward to R0 destination.
//////////////////////////////////////////////////////////////////////////////////
module forward_unit (
    // EX/MEM stage info (instruction now completing EX)
    input  wire        ex_mem_reg_write,
    input  wire [2:0]  ex_mem_rd,

    // MEM/WB stage info (instruction now completing MEM)
    input  wire        mem_wb_reg_write,
    input  wire [2:0]  mem_wb_rd,

    // ID/EX stage info (instruction now in EX — needs operands)
    input  wire [2:0]  id_ex_rs1,
    input  wire [2:0]  id_ex_rs2,

    // Forwarding mux selects
    // 2'b00 = use register file (no forward)
    // 2'b10 = forward from EX/MEM (one stage back)
    // 2'b01 = forward from MEM/WB (two stages back)
    output reg  [1:0]  forward_a,   // select for ALU input A (rs1)
    output reg  [1:0]  forward_b    // select for ALU input B (rs2)
);
    always @(*) begin
        // ---- ALU input A (rs1) ----
        if (ex_mem_reg_write &&
            (ex_mem_rd != 3'd0) &&
            (ex_mem_rd == id_ex_rs1))
            forward_a = 2'b10;  // EX forward
        else if (mem_wb_reg_write &&
                 (mem_wb_rd != 3'd0) &&
                 (mem_wb_rd == id_ex_rs1))
            forward_a = 2'b01;  // MEM forward
        else
            forward_a = 2'b00;  // no forward

        // ---- ALU input B (rs2) ----
        if (ex_mem_reg_write &&
            (ex_mem_rd != 3'd0) &&
            (ex_mem_rd == id_ex_rs2))
            forward_b = 2'b10;  // EX forward
        else if (mem_wb_reg_write &&
                 (mem_wb_rd != 3'd0) &&
                 (mem_wb_rd == id_ex_rs2))
            forward_b = 2'b01;  // MEM forward
        else
            forward_b = 2'b00;  // no forward
    end
endmodule
