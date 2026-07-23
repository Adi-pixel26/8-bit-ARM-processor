`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name : uart_tx
// Description : 8N1 UART transmitter (8 data bits, no parity, 1 stop bit).
//
// Operation:
//   When the CPU writes a byte to the UART TX register (via io_bus), it pulses
//   tx_valid=1 for one cycle with tx_data holding the byte to send.
//   The module serializes it at the configured baud rate and asserts tx_busy=1
//   until the full frame has been sent.
//
// Baud rate:
//   baud_div = clk_freq / baud_rate
//   Example: 50 MHz clock, 115200 baud → baud_div = 50000000/115200 ≈ 434
//   Set BAUD_DIV parameter when instantiating.
//
// Frame format: [START=0][D0][D1][D2][D3][D4][D5][D6][D7][STOP=1]
//
// tx line idles HIGH (1). Start bit pulls it LOW. Stop bit returns HIGH.
//////////////////////////////////////////////////////////////////////////////////
module uart_tx #(
    parameter BAUD_DIV = 434    // 50MHz / 115200 baud
)(
    input  wire       clk,
    input  wire       reset,
    input  wire       tx_valid,  // pulse 1 cycle to send tx_data
    input  wire [7:0] tx_data,   // byte to transmit
    output wire       tx_busy,   // 1 = currently transmitting
    output reg        tx         // serial output line
);
    // State machine
    localparam IDLE  = 2'd0;
    localparam START = 2'd1;
    localparam DATA  = 2'd2;
    localparam STOP  = 2'd3;

    reg [1:0]  state;
    reg [15:0] baud_cnt;    // counts down to next bit period
    reg [3:0]  bit_idx;     // which data bit we're sending (0..7)
    reg [7:0]  shift_reg;   // copy of tx_data, shifted out LSB first

    assign tx_busy = (state != IDLE);

    always @(posedge clk) begin
        if (reset) begin
            state    <= IDLE;
            tx       <= 1'b1;   // idle HIGH
            baud_cnt <= 0;
            bit_idx  <= 0;
            shift_reg<= 0;
        end else begin
            case (state)
                IDLE: begin
                    tx <= 1'b1;
                    if (tx_valid && !tx_busy) begin
                        shift_reg <= tx_data;
                        baud_cnt  <= BAUD_DIV - 1;
                        state     <= START;
                    end
                end

                START: begin
                    tx <= 1'b0;             // start bit
                    if (baud_cnt == 0) begin
                        baud_cnt <= BAUD_DIV - 1;
                        bit_idx  <= 0;
                        state    <= DATA;
                    end else
                        baud_cnt <= baud_cnt - 1;
                end

                DATA: begin
                    tx <= shift_reg[0];     // LSB first
                    if (baud_cnt == 0) begin
                        shift_reg <= {1'b0, shift_reg[7:1]}; // shift right
                        baud_cnt  <= BAUD_DIV - 1;
                        if (bit_idx == 7) begin
                            state <= STOP;
                        end else begin
                            bit_idx <= bit_idx + 1;
                        end
                    end else
                        baud_cnt <= baud_cnt - 1;
                end

                STOP: begin
                    tx <= 1'b1;             // stop bit
                    if (baud_cnt == 0) begin
                        state <= IDLE;
                    end else
                        baud_cnt <= baud_cnt - 1;
                end
            endcase
        end
    end
endmodule
