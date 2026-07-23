`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name : register_file
// Description : 8 x 8-bit register file.
//               R0 is hardwired to 0 — writes to R0 are ignored.
//               Synchronous write, asynchronous read.
//////////////////////////////////////////////////////////////////////////////////
module register_file (
    input  wire       clk,
    input  wire       reg_write,
    input  wire [2:0] read_reg1,
    input  wire [2:0] read_reg2,
    input  wire [2:0] write_reg,
    input  wire [7:0] write_data,
    output wire [7:0] read_data1,
    output wire [7:0] read_data2
);
    reg [7:0] registers [0:7];

    integer i;
    initial begin
        for (i = 0; i < 8; i = i + 1)
            registers[i] = 8'd0;
    end

    // Synchronous write — R0 is always 0
    always @(posedge clk) begin
        if (reg_write && write_reg != 3'd0)
            registers[write_reg] <= write_data;
    end

    // Asynchronous read — R0 always reads 0
   // FIX - write-first register file
// If the register being read is the same one being written this cycle,
// return the new write_data instead of the stale stored value.
assign read_data1 = (read_reg1 == 3'd0) ? 8'd0 :
                    (reg_write && write_reg == read_reg1) ? write_data :
                    registers[read_reg1];

assign read_data2 = (read_reg2 == 3'd0) ? 8'd0 :
                    (reg_write && write_reg == read_reg2) ? write_data :
                    registers[read_reg2];
endmodule
