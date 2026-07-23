`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name : hazard_unit
// Description : Detects RAW (Read After Write) data hazards and generates
//               stall signals to freeze the pipeline when forwarding cannot help.
//
// The only case that CANNOT be resolved by forwarding is a load-use hazard:
//   LDR R1, [R0+0]     ← in EX stage, result not available until MEM
//   ADD R2, R1, R3     ← in ID stage, needs R1 right now
//
// In this case we must stall for 1 cycle:
//   - PC and IF/ID register are frozen (stall_pc, stall_if_id = 1)
//   - ID/EX register is flushed (nop_id_ex = 1) — inserts a bubble
//
// All other RAW hazards are handled by the forwarding unit with no stall.
//
// Ports:
//   id_ex_mem_read   — is the instruction in EX stage a LDR?
//   id_ex_rd         — destination register of instruction in EX
//   if_id_rs1        — source register 1 of instruction in ID
//   if_id_rs2        — source register 2 of instruction in ID
//   stall_pc         — freeze the program counter
//   stall_if_id      — freeze the IF/ID pipeline register
//   nop_id_ex        — flush ID/EX register (insert bubble into EX)
//////////////////////////////////////////////////////////////////////////////////
module hazard_unit (
    input  wire        id_ex_mem_read,  // 1 if EX instruction is LDR
    input  wire [2:0]  id_ex_rd,        // destination of EX instruction
    input  wire [2:0]  if_id_rs1,       // source 1 of ID instruction
    input  wire [2:0]  if_id_rs2,       // source 2 of ID instruction
    output wire        stall_pc,        // freeze PC
    output wire        stall_if_id,     // freeze IF/ID register
    output wire        nop_id_ex        // flush ID/EX (insert NOP bubble)
);
    // Load-use hazard: EX is a LDR and its destination matches
    // either source of the ID instruction
    wire load_use_hazard;
    assign load_use_hazard = id_ex_mem_read &&
                             ((id_ex_rd == if_id_rs1) ||
                              (id_ex_rd == if_id_rs2));

    assign stall_pc    = load_use_hazard;
    assign stall_if_id = load_use_hazard;
    assign nop_id_ex   = load_use_hazard;

endmodule
