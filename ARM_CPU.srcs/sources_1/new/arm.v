`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name : arm (ALU)
// Description : 8-bit ALU - updated for Phase 1.
//
// alu_op encoding (3-bit, from control_unit):
//   000 = ADD   {carry,result} = A + B
//   001 = SUB   {carry,result} = A - B
//   010 = AND   result = A & B
//   011 = OR    result = A | B
//   100 = XOR   result = A ^ B
//   101 = MOV   result = B        (pass immediate through)
//   110 = LSL   result = A << 1   (logical shift left by 1)
//   111 = LSR   result = A >> 1   (logical shift right by 1)
//
// NOT is handled as a pseudo-instruction in the control unit:
//   NOT Rd, Rs1  →  XOR Rs1, 0xFF  (alu_src=1, imm=0xFF extended)
//   Since imm3 is only 3 bits (max=7), NOT uses a dedicated
//   control path - see control_unit.v for details.
//
// Flags:
//   zero  = (result == 0)  - used by BEQ/BNE branch logic
//   carry = carry-out of ADD/SUB, 0 for all other ops
//////////////////////////////////////////////////////////////////////////////////
module arm(
    input  wire [7:0] A,
    input  wire [7:0] B,
    input  wire [2:0] alu_op,
    output reg  [7:0] result,
    output reg        carry,
    output reg        zero
);
    always @(*) begin
        result = 8'd0;
        carry  = 1'b0;

        case (alu_op)
            3'b000: {carry, result} = A + B;   // ADD
            3'b001: {carry, result} = A - B;   // SUB
            3'b010: result = A & B;             // AND
            3'b011: result = A | B;             // OR
            3'b100: result = A ^ B;             // XOR
            3'b101: result = B;                 // MOV - pass B (immediate) through
            3'b110: result = A << 1;            // LSL - shift left 1
            3'b111: result = A >> 1;            // LSR - shift right 1
            default: result = 8'd0;
        endcase

        zero = (result == 8'd0);
    end
endmodule
