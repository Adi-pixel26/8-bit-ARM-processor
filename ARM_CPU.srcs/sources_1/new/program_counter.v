`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name : program_counter
// Description : 8-bit PC with stall support for pipeline hazards.
//               stall=1 → hold current PC (do not increment or branch)
//               branch_taken has no effect when stall is asserted.
//////////////////////////////////////////////////////////////////////////////////
module program_counter (
    input  wire       clk,
    input  wire       reset,
    input  wire       stall,          // 1 = freeze PC (hazard stall)
    input  wire       branch_taken,
    input  wire [7:0] branch_target,
    output reg  [7:0] pc
);
    always @(posedge clk) begin
        if (reset)
            pc <= 8'd0;
        else if (stall)
            pc <= pc;              // hold
        else if (branch_taken)
            pc <= branch_target;
        else
            pc <= pc + 8'd1;
    end
endmodule
