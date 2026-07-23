`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name : control_unit
// Description : Instruction decoder - updated for Phase 1.
//
// Full opcode table (4-bit):
//   0000 = ADD   R[rd] = R[rs1] + R[rs2]
//   0001 = MOV   R[rd] = imm3          (alu_src=1, ALU passes B through)
//   0010 = SUB   R[rd] = R[rs1] - R[rs2]
//   0011 = AND   R[rd] = R[rs1] & R[rs2]
//   0100 = OR    R[rd] = R[rs1] | R[rs2]
//   0101 = XOR   R[rd] = R[rs1] ^ R[rs2]
//   0110 = LDR   R[rd] = sram[R[rs1] + imm3]
//   0111 = STR   sram[R[rs1] + imm3] = R[rs2]
//   1000 = BEQ   branch if zero flag set
//   1001 = BNE   branch if zero flag clear
//   1010 = BRA   unconditional branch
//   1011 = LSL   R[rd] = R[rs1] << 1   (NEW Phase 1)
//   1100 = LSR   R[rd] = R[rs1] >> 1   (NEW Phase 1)
//   1101 = NOT   R[rd] = ~R[rs1]       (NEW Phase 1 - uses inv_a flag)
//   1110 = CMP   sets zero/carry flags, no writeback  (NEW Phase 1)
//
// New output - inv_a:
//   When inv_a=1, the datapath inverts A before the ALU (for NOT).
//   The top-level arm_processor.v must implement:
//     wire [7:0] alu_a = inv_a ? ~reg_data1 : reg_data1;
//   and connect alu_a to ALU port A instead of reg_data1 directly.
//
// ALU op encoding (must match arm.v):
//   000=ADD  001=SUB  010=AND  011=OR  100=XOR  101=MOV  110=LSL  111=LSR
//////////////////////////////////////////////////////////////////////////////////
module control_unit (
    input  wire [3:0] opcode,
    output reg        reg_write,
    output reg        mem_read,
    output reg        mem_write,
    output reg        mem_to_reg,   // 1 = writeback from SRAM, 0 = from ALU
    output reg        alu_src,      // 1 = B is imm3, 0 = B is rs2
    output reg  [2:0] alu_op,
    output reg        branch,
    output reg        branch_cond,
    output reg        inv_a,        // NEW: 1 = invert A before ALU (NOT instruction)
    output reg        sram_cs,      // NEW: SRAM chip select (replaces mem_read gating)
    output reg        sram_oe,      // NEW: SRAM output enable
    output reg        sram_we       // NEW: SRAM write enable
);
    // ALU op localparams - match arm.v exactly
    localparam ALU_ADD = 3'b000;
    localparam ALU_SUB = 3'b001;
    localparam ALU_AND = 3'b010;
    localparam ALU_OR  = 3'b011;
    localparam ALU_XOR = 3'b100;
    localparam ALU_MOV = 3'b101;
    localparam ALU_LSL = 3'b110;
    localparam ALU_LSR = 3'b111;

    always @(*) begin
        // Safe defaults - NOP behaviour
        reg_write   = 0;
        mem_read    = 0;
        mem_write   = 0;
        mem_to_reg  = 0;
        alu_src     = 0;
        alu_op      = ALU_ADD;
        branch      = 0;
        branch_cond = 0;
        inv_a       = 0;
        sram_cs     = 0;
        sram_oe     = 0;
        sram_we     = 0;

        case (opcode)
            4'b0000: begin // ADD
                reg_write = 1;
                alu_op    = ALU_ADD;
            end
            4'b0001: begin // MOV imm
                reg_write = 1;
                alu_src   = 1;
                alu_op    = ALU_MOV;
            end
            4'b0010: begin // SUB
                reg_write = 1;
                alu_op    = ALU_SUB;
            end
            4'b0011: begin // AND
                reg_write = 1;
                alu_op    = ALU_AND;
            end
            4'b0100: begin // OR
                reg_write = 1;
                alu_op    = ALU_OR;
            end
            4'b0101: begin // XOR
                reg_write = 1;
                alu_op    = ALU_XOR;
            end
            4'b0110: begin // LDR - load from SRAM
                reg_write  = 1;
                mem_read   = 1;
                mem_to_reg = 1;
                alu_src    = 1;      // address = rs1 + imm3
                alu_op     = ALU_ADD;
                sram_cs    = 1;
                sram_oe    = 1;
                sram_we    = 0;
            end
            4'b0111: begin // STR - store to SRAM
                mem_write = 1;
                alu_src   = 1;      // address = rs1 + imm3
                alu_op    = ALU_ADD;
                sram_cs   = 1;
                sram_oe   = 0;
                sram_we   = 1;
            end
            4'b1000: begin // BEQ
                branch      = 1;
                branch_cond = 1;
            end
            4'b1001: begin // BNE
                branch      = 1;
                branch_cond = 0;
            end
            4'b1010: begin // BRA unconditional
                branch      = 1;
                branch_cond = 1;
            end
            4'b1011: begin // LSL - shift left
                reg_write = 1;
                alu_op    = ALU_LSL;
            end
            4'b1100: begin // LSR - shift right
                reg_write = 1;
                alu_op    = ALU_LSR;
            end
            4'b1101: begin // NOT - bitwise invert rs1
                reg_write = 1;
                inv_a     = 1;      // top-level inverts A before ALU
                alu_op    = ALU_MOV; // ALU passes inverted A (now B=A after inv) through
                // Actually: inv_a inverts reg_data1, then MOV passes it as result
                // See arm_processor.v for the alu_a mux
            end
            4'b1110: begin // CMP - subtract, set flags, no writeback
                reg_write = 0;      // flags update but no register write
                alu_op    = ALU_SUB;
            end
            default: ; // NOP
        endcase
    end
endmodule
