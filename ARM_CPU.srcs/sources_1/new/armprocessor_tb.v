`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name : armprocessor_tb (pipelined)
// Description : Testbench for the 5-stage pipelined arm_processor.
//
// IMPORTANT — pipelining changes timing:
//   Instructions now take 5 cycles to complete (one per stage).
//   The first result appears at cycle 5. We run more cycles to let
//   all instructions fully drain through the pipeline before checking.
//
// Test program (same as Phase 1 — result values unchanged):
//   [0] MOV R1, #5
//   [1] MOV R2, #3
//   [2] ADD R3, R1, R2    RAW hazard on R1,R2 — forwarding handles it
//   [3] SUB R4, R3, R2    RAW hazard on R3    — forwarding handles it
//   [4] AND R5, R3, R2    RAW hazard on R3    — forwarding handles it
//   [5] OR  R5, R3, R2    RAW hazard on R3    — forwarding handles it
//   [6] XOR R6, R3, R2    RAW hazard on R3    — forwarding handles it
//   [7] NOP
//
// Expected final register values:
//   R1=5  R2=3  R3=8  R4=5  R5=11  R6=11
//////////////////////////////////////////////////////////////////////////////////
module armprocessor_tb;

    reg clk;
    reg reset;

    arm_processor DUT (
        .clk  (clk),
        .reset(reset)
    );

    initial clk = 0;
    always  #5 clk = ~clk;

    initial begin
        $dumpfile("armprocessor_tb.vcd");
        $dumpvars(0, armprocessor_tb);
    end

    task check_reg;
        input [2:0]   reg_num;
        input [7:0]   expected;
        input integer test_id;
        begin
            if (DUT.RF.registers[reg_num] !== expected)
                $display("FAIL [T%0d] R%0d = %0d (0x%02X)  expected %0d (0x%02X)  @ %0t ns",
                          test_id, reg_num,
                          DUT.RF.registers[reg_num], DUT.RF.registers[reg_num],
                          expected, expected, $time);
            else
                $display("PASS [T%0d] R%0d = %0d", test_id, reg_num,
                          DUT.RF.registers[reg_num]);
        end
    endtask

    integer i;

    initial begin
        // Step 1 — assert reset
        reset = 1;
        repeat(4) @(posedge clk);
        #1;

        // Step 2 — load instruction memory while reset high
        for (i = 0; i < 256; i = i + 1)
            DUT.FETCH.u_imem.mem[i] = 16'h0000;

        // [0] MOV R1, #5
        DUT.FETCH.u_imem.mem[0] = 16'b0001_001_000_000_101;
        // [1] MOV R2, #3
        DUT.FETCH.u_imem.mem[1] = 16'b0001_010_000_000_011;
        // [2] ADD R3, R1, R2
        DUT.FETCH.u_imem.mem[2] = 16'b0000_011_001_010_000;
        // [3] SUB R4, R3, R2
        DUT.FETCH.u_imem.mem[3] = 16'b0010_100_011_010_000;
        // [4] AND R5, R3, R2
        DUT.FETCH.u_imem.mem[4] = 16'b0011_101_011_010_000;
        // [5] OR  R5, R3, R2
        DUT.FETCH.u_imem.mem[5] = 16'b0100_101_011_010_000;
        // [6] XOR R6, R3, R2
        DUT.FETCH.u_imem.mem[6] = 16'b0101_110_011_010_000;
        // [7..] NOP
        DUT.FETCH.u_imem.mem[7] = 16'h0000;

        // Step 3 — release reset
        @(posedge clk); #1;
        reset = 0;

        $display("\n========================================");
        $display("  ARM 8-bit Pipelined Processor TB");
        $display("  Reset released @ %0t ns", $time);
        $display("========================================\n");

        // Step 4 — run enough cycles for pipeline to drain
        // 7 instructions + 5 pipeline stages + hazard stalls = ~20 cycles
        repeat(30) @(posedge clk);
        #1;

        // Step 5 — check results
        $display("--- Register File Checks ---");
        check_reg(3'd1, 8'd5,  1);
        check_reg(3'd2, 8'd3,  2);
        check_reg(3'd3, 8'd8,  3);
        check_reg(3'd4, 8'd5,  4);
        check_reg(3'd5, 8'd11, 5);
        check_reg(3'd6, 8'd11, 6);
        $display("");

        $display("========================================");
        $display("  Testbench Complete @ %0t ns", $time);
        $display("========================================\n");
        $finish;
    end

    // Per-cycle trace — shows all 5 stages simultaneously
    always @(posedge clk) begin
        if (!reset)
            $display("[%0t ns] IF:PC=%0d | ID:op=%b rd=%0d | EX:alu=%0d fwdA=%b fwdB=%b | WB:rd=%0d wb=%0d rw=%b | stall=%b",
                $time,
                DUT.if_pc,
                DUT.id_opcode, DUT.id_rd,
                DUT.ex_alu_result, DUT.forward_a, DUT.forward_b,
                DUT.wb_rd, DUT.wb_data, DUT.wb_reg_write,
                DUT.stall_pc);
    end

    initial begin
        #20000;
        $display("TIMEOUT");
        $finish;
    end

endmodule
