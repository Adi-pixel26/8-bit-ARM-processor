`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name : sram
// Description : 256 x 8-bit synchronous SRAM model.
//
//               Models real SRAM behaviour (e.g. IS61WV256):
//                 cs  - chip select  (active HIGH)
//                 oe  - output enable (active HIGH) - gates read data onto bus
//                 we  - write enable  (active HIGH) - latches write on posedge clk
//
//               Truth table:
//                 cs=0              → device disabled, read_data = 8'hZZ
//                 cs=1, we=1        → write address←write_data on posedge clk
//                 cs=1, we=0, oe=1  → read_data = mem[address]
//                 cs=1, we=0, oe=0  → read_data = 8'hZZ (output disabled)
//
//               Tri-state output (8'hZZ) when disabled mimics real SRAM chips.
//               For FPGA simulation this is fine; for synthesis swap ZZ→8'h00
//               if your tool doesn't support tri-state on internal signals.
//
// Replaces   : datamem.v (which had no CS/OE control)
//////////////////////////////////////////////////////////////////////////////////
module sram (
    input  wire       clk,
    input  wire       cs,           // chip select   - active HIGH
    input  wire       oe,           // output enable - active HIGH
    input  wire       we,           // write enable  - active HIGH
    input  wire [7:0] address,
    input  wire [7:0] write_data,
    output wire [7:0] read_data
);
    // 256 x 8-bit storage array
    reg [7:0] mem [0:255];

    // Initialise to 0 (aids simulation - avoids X on first read)
    integer i;
    initial begin
        for (i = 0; i < 256; i = i + 1)
            mem[i] = 8'd0;
    end

    // Synchronous write - only when cs=1 AND we=1
    always @(posedge clk) begin
        if (cs && we)
            mem[address] <= write_data;
    end

    // Asynchronous read with tri-state output control
    // cs=1, we=0, oe=1  → drive data
    // anything else     → high-impedance (disabled)
    assign read_data = (cs && !we && oe) ? mem[address] : 8'hZZ;

endmodule
