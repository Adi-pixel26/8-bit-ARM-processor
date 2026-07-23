`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name : datamem
// Description : 256 x 8-bit synchronous write, asynchronous read data memory.
//////////////////////////////////////////////////////////////////////////////////
module datamem (
    input  wire       clk,
    input  wire       mem_read,
    input  wire       mem_write,
    input  wire [7:0] address,
    input  wire [7:0] write_data,
    output wire [7:0] read_data
);
    reg [7:0] mem [0:255];

    integer i;
    initial begin
        for (i = 0; i < 256; i = i + 1)
            mem[i] = 8'd0;
    end

    // Synchronous write
    always @(posedge clk) begin
        if (mem_write)
            mem[address] <= write_data;
    end

    // Asynchronous read
    assign read_data = mem_read ? mem[address] : 8'd0;
endmodule
