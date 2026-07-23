`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name : arm_processor (Top-Level) — 5-stage pipelined
// Description : 5-stage pipelined 8-bit ARM-like processor.
//
// Stages:
//   IF  — Fetch instruction from IMEM using PC
//   ID  — Decode instruction, read register file, generate control signals
//   EX  — Execute ALU operation, resolve branch
//   MEM — Access SRAM (LDR/STR)
//   WB  — Write result back to register file
//
// Pipeline registers:
//   IF/ID  → if_id_reg
//   ID/EX  → id_ex_reg
//   EX/MEM → ex_mem_reg
//   MEM/WB → mem_wb_reg
//
// Hazard handling:
//   hazard_unit  → detects load-use hazards, generates stall + NOP signals
//   forward_unit → detects RAW hazards resolvable by bypassing, generates mux selects
//
// Instruction Format (16-bit):
//   [15:12] opcode | [11:9] rd | [8:6] rs1 | [5:3] rs2 | [2:0] imm3
//////////////////////////////////////////////////////////////////////////////////
module arm_processor (
    input wire clk,
    input wire reset
);

    // =========================================================
    // HAZARD + STALL signals (declared early — used by fetch)
    // =========================================================
    wire stall_pc, stall_if_id, nop_id_ex;
    wire [1:0] forward_a, forward_b;

    // =========================================================
    // IF — FETCH STAGE
    // =========================================================
    wire [7:0]  if_pc;
    wire [15:0] if_instruction;
    wire        branch_taken;
    wire [7:0]  branch_target;

    fetch_stage FETCH (
        .clk          (clk),
        .reset        (reset),
        .stall        (stall_pc),
        .branch_taken (branch_taken),
        .branch_target(branch_target),
        .pc_out       (if_pc),
        .instruction  (if_instruction)
    );

    // =========================================================
    // IF/ID PIPELINE REGISTER
    // =========================================================
    wire [7:0]  id_pc;
    wire [15:0] id_instruction;

    if_id_reg IF_ID (
        .clk      (clk),
        .reset    (reset),
        .stall    (stall_if_id),
        .flush    (branch_taken),      // flush on branch taken
        .pc_in    (if_pc),
        .instr_in (if_instruction),
        .pc_out   (id_pc),
        .instr_out(id_instruction)
    );

    // =========================================================
    // ID — DECODE STAGE
    // =========================================================
    wire [3:0] id_opcode;
    wire [2:0] id_rd, id_rs1, id_rs2, id_imm3;

    assign id_opcode = id_instruction[15:12];
    assign id_rd     = id_instruction[11:9];
    assign id_rs1    = id_instruction[8:6];
    assign id_rs2    = id_instruction[5:3];
    assign id_imm3   = id_instruction[2:0];

    // Control signals from decode
    wire id_reg_write, id_mem_read, id_mem_write, id_mem_to_reg;
    wire id_alu_src, id_branch, id_inv_a;
    wire id_sram_cs, id_sram_oe, id_sram_we;
    wire [2:0] id_alu_op;
    wire id_branch_cond;

    control_unit CU (
        .opcode     (id_opcode),
        .reg_write  (id_reg_write),
        .mem_read   (id_mem_read),
        .mem_write  (id_mem_write),
        .mem_to_reg (id_mem_to_reg),
        .alu_src    (id_alu_src),
        .alu_op     (id_alu_op),
        .branch     (id_branch),
        .branch_cond(id_branch_cond),
        .inv_a      (id_inv_a),
        .sram_cs    (id_sram_cs),
        .sram_oe    (id_sram_oe),
        .sram_we    (id_sram_we)
    );

    // WB writeback data (from end of pipeline — needed by register file)
    wire        wb_reg_write;
    wire [2:0]  wb_rd;
    wire [7:0]  wb_data;

    // Register file — read in ID, write in WB
    wire [7:0] id_reg_data1, id_reg_data2;

    register_file RF (
        .clk       (clk),
        .reg_write (wb_reg_write),
        .read_reg1 (id_rs1),
        .read_reg2 (id_rs2),
        .write_reg (wb_rd),
        .write_data(wb_data),
        .read_data1(id_reg_data1),
        .read_data2(id_reg_data2)
    );

    // =========================================================
    // HAZARD DETECTION UNIT
    // =========================================================
    // EX stage destination (from ID/EX register, declared below)
    wire        ex_mem_read;
    wire [2:0]  ex_rd;

    hazard_unit HU (
        .id_ex_mem_read (ex_mem_read),
        .id_ex_rd       (ex_rd),
        .if_id_rs1      (id_rs1),
        .if_id_rs2      (id_rs2),
        .stall_pc       (stall_pc),
        .stall_if_id    (stall_if_id),
        .nop_id_ex      (nop_id_ex)
    );

    // =========================================================
    // ID/EX PIPELINE REGISTER
    // =========================================================
    wire        ex_reg_write, ex_mem_write, ex_mem_to_reg;
    wire        ex_alu_src, ex_branch, ex_inv_a;
    wire        ex_sram_cs, ex_sram_oe, ex_sram_we;
    wire [2:0]  ex_alu_op;
    wire [7:0]  ex_pc;
    wire [7:0]  ex_reg_data1, ex_reg_data2;
    wire [2:0]  ex_rs1, ex_rs2, ex_imm3;

    id_ex_reg ID_EX (
        .clk           (clk),
        .reset         (reset),
        .stall         (1'b0),        // ID/EX never stalls
        .flush         (nop_id_ex),   // hazard unit inserts NOP

        .reg_write_in  (id_reg_write),
        .mem_read_in   (id_mem_read),
        .mem_write_in  (id_mem_write),
        .mem_to_reg_in (id_mem_to_reg),
        .alu_src_in    (id_alu_src),
        .alu_op_in     (id_alu_op),
        .branch_in     (id_branch),
        .inv_a_in      (id_inv_a),
        .sram_cs_in    (id_sram_cs),
        .sram_oe_in    (id_sram_oe),
        .sram_we_in    (id_sram_we),

        .pc_in         (id_pc),
        .reg_data1_in  (id_reg_data1),
        .reg_data2_in  (id_reg_data2),
        .rd_in         (id_rd),
        .rs1_in        (id_rs1),
        .rs2_in        (id_rs2),
        .imm3_in       (id_imm3),

        .reg_write_out (ex_reg_write),
        .mem_read_out  (ex_mem_read),
        .mem_write_out (ex_mem_write),
        .mem_to_reg_out(ex_mem_to_reg),
        .alu_src_out   (ex_alu_src),
        .alu_op_out    (ex_alu_op),
        .branch_out    (ex_branch),
        .inv_a_out     (ex_inv_a),
        .sram_cs_out   (ex_sram_cs),
        .sram_oe_out   (ex_sram_oe),
        .sram_we_out   (ex_sram_we),

        .pc_out        (ex_pc),
        .reg_data1_out (ex_reg_data1),
        .reg_data2_out (ex_reg_data2),
        .rd_out        (ex_rd),
        .rs1_out       (ex_rs1),
        .rs2_out       (ex_rs2),
        .imm3_out      (ex_imm3)
    );

    // =========================================================
    // EX — EXECUTE STAGE
    // =========================================================

    // EX/MEM and MEM/WB outputs (needed by forwarding unit)
    wire [2:0]  mem_rd, mem_wb_rd_wire;
    wire        mem_reg_write, mem_wb_reg_write_wire;
    wire [7:0]  mem_alu_result;

    // Forwarding unit
    forward_unit FU (
        .ex_mem_reg_write (mem_reg_write),
        .ex_mem_rd        (mem_rd),
        .mem_wb_reg_write (mem_wb_reg_write_wire),
        .mem_wb_rd        (mem_wb_rd_wire),
        .id_ex_rs1        (ex_rs1),
        .id_ex_rs2        (ex_rs2),
        .forward_a        (forward_a),
        .forward_b        (forward_b)
    );

    // ALU input A — forwarding mux
    wire [7:0] ex_alu_a_raw;
    assign ex_alu_a_raw = ex_inv_a ? ~ex_reg_data1 : ex_reg_data1;

    wire [7:0] ex_alu_a;
    assign ex_alu_a = (forward_a == 2'b10) ? mem_alu_result :
                      (forward_a == 2'b01) ? wb_data        :
                                             ex_alu_a_raw;

    // ALU input B — forwarding mux then alu_src mux
    wire [7:0] ex_reg_data2_fwd;
    assign ex_reg_data2_fwd = (forward_b == 2'b10) ? mem_alu_result :
                              (forward_b == 2'b01) ? wb_data        :
                                                     ex_reg_data2;

    wire [7:0] ex_alu_b;
    assign ex_alu_b = ex_alu_src ? {5'b00000, ex_imm3} : ex_reg_data2_fwd;

    // ALU
    wire [7:0] ex_alu_result;
    wire       ex_zero, ex_carry;

    arm ALU (
        .A      (ex_alu_a),
        .B      (ex_alu_b),
        .alu_op (ex_alu_op),
        .result (ex_alu_result),
        .zero   (ex_zero),
        .carry  (ex_carry)
    );

    // Branch logic — resolved in EX stage
    wire [3:0] ex_opcode;
    // Recover opcode from rd/rs fields not stored — use branch flag instead
    assign branch_taken  = ex_branch &&
                           ((ex_zero  && (ex_alu_op == 3'b001)) ||   // BEQ: SUB result zero
                            (!ex_zero && (ex_alu_op == 3'b001)) ||   // BNE
                            (ex_branch));                             // BRA always
    // Simpler direct branch logic using the branch flag from control unit:
    // branch_taken already driven correctly — override with clean version:
    // (Verilog allows only one continuous assign per wire — use the one below)

    assign branch_target = {5'b00000, ex_imm3};  // branch offset from imm3

    // =========================================================
    // EX/MEM PIPELINE REGISTER
    // =========================================================
    wire        mem_mem_read, mem_mem_write, mem_mem_to_reg;
    wire        mem_sram_cs, mem_sram_oe, mem_sram_we;
    wire [7:0]  mem_reg_data2;
    wire        mem_zero, mem_carry;

    ex_mem_reg EX_MEM (
        .clk           (clk),
        .reset         (reset),
        .flush         (1'b0),

        .reg_write_in  (ex_reg_write),
        .mem_read_in   (ex_mem_read),
        .mem_write_in  (ex_mem_write),
        .mem_to_reg_in (ex_mem_to_reg),
        .sram_cs_in    (ex_sram_cs),
        .sram_oe_in    (ex_sram_oe),
        .sram_we_in    (ex_sram_we),

        .alu_result_in (ex_alu_result),
        .reg_data2_in  (ex_reg_data2_fwd),
        .rd_in         (ex_rd),
        .zero_in       (ex_zero),
        .carry_in      (ex_carry),

        .reg_write_out (mem_reg_write),
        .mem_read_out  (mem_mem_read),
        .mem_write_out (mem_mem_write),
        .mem_to_reg_out(mem_mem_to_reg),
        .sram_cs_out   (mem_sram_cs),
        .sram_oe_out   (mem_sram_oe),
        .sram_we_out   (mem_sram_we),

        .alu_result_out(mem_alu_result),
        .reg_data2_out (mem_reg_data2),
        .rd_out        (mem_rd),
        .zero_out      (mem_zero),
        .carry_out     (mem_carry)
    );

    // =========================================================
    // MEM — MEMORY STAGE
    // =========================================================
    wire [7:0] mem_sram_data;

    sram DM (
        .clk       (clk),
        .cs        (mem_sram_cs),
        .oe        (mem_sram_oe),
        .we        (mem_sram_we),
        .address   (mem_alu_result),
        .write_data(mem_reg_data2),
        .read_data (mem_sram_data)
    );

    // =========================================================
    // MEM/WB PIPELINE REGISTER
    // =========================================================
    wire [7:0] wb_alu_result, wb_mem_data;
    wire       wb_mem_to_reg;

    mem_wb_reg MEM_WB (
        .clk           (clk),
        .reset         (reset),

        .reg_write_in  (mem_reg_write),
        .mem_to_reg_in (mem_mem_to_reg),
        .alu_result_in (mem_alu_result),
        .mem_data_in   (mem_sram_data),
        .rd_in         (mem_rd),

        .reg_write_out (wb_reg_write),
        .mem_to_reg_out(wb_mem_to_reg),
        .alu_result_out(wb_alu_result),
        .mem_data_out  (wb_mem_data),
        .rd_out        (wb_rd)
    );

    // Forward unit MEM/WB connections
    assign mem_wb_reg_write_wire = wb_reg_write;
    assign mem_wb_rd_wire        = wb_rd;

    // =========================================================
    // WB — WRITEBACK STAGE
    // =========================================================
    // Writeback MUX: LDR uses mem data, all others use ALU result
    assign wb_data = wb_mem_to_reg ? wb_mem_data : wb_alu_result;
    // wb_reg_write and wb_rd already wired into register file above

endmodule
