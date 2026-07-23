`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name : uart_rx
// Description : 8N1 UART receiver (8 data bits, no parity, 1 stop bit).
//
// Operation:
//   Detects the falling edge of the start bit on the rx line.
//   Samples each bit at the middle of its baud period (most reliable point).
//   When a full byte is received, pulses rx_valid=1 for one cycle and puts
//   the byte on rx_data.
//
// The CPU reads the received byte by reading from the UART RX address (0xF1).
// The io_bus latches rx_data when rx_valid fires.
//
// Frame format: [START=0][D0][D1][D2][D3][D4][D5][D6][D7][STOP=1]
//////////////////////////////////////////////////////////////////////////////////
module uart_rx #(
    parameter BAUD_DIV = 434    // 50MHz / 115200 baud
)(
    input  wire       clk,
    input  wire       reset,
    input  wire       rx,        // serial input line
    output reg        rx_valid,  // pulses 1 cycle when byte received
    output reg  [7:0] rx_data    // received byte
);
    localparam IDLE  = 2'd0;
    localparam START = 2'd1;
    localparam DATA  = 2'd2;
    localparam STOP  = 2'd3;

    reg [1:0]  state;
    reg [15:0] baud_cnt;
    reg [3:0]  bit_idx;
    reg [7:0]  shift_reg;
    reg        rx_sync0, rx_sync1;  // 2-FF synchronizer for rx input

    // Synchronize async rx input to clk domain
    always @(posedge clk) begin
        rx_sync0 <= rx;
        rx_sync1 <= rx_sync0;
    end

    wire rx_s = rx_sync1;

    always @(posedge clk) begin
        if (reset) begin
            state    <= IDLE;
            rx_valid <= 0;
            rx_data  <= 0;
            baud_cnt <= 0;
            bit_idx  <= 0;
            shift_reg<= 0;
        end else begin
            rx_valid <= 0; // default — only high for 1 cycle

            case (state)
                IDLE: begin
                    if (!rx_s) begin    // falling edge = start bit
                        // Sample in the middle of the start bit
                        baud_cnt <= (BAUD_DIV >> 1) - 1;
                        state    <= START;
                    end
                end

                START: begin
                    if (baud_cnt == 0) begin
                        if (!rx_s) begin    // confirm still low at mid-point
                            baud_cnt <= BAUD_DIV - 1;
                            bit_idx  <= 0;
                            state    <= DATA;
                        end else
                            state <= IDLE;  // false start, go back
                    end else
                        baud_cnt <= baud_cnt - 1;
                end

                DATA: begin
                    if (baud_cnt == 0) begin
                        // Sample bit at middle of baud period
                        shift_reg <= {rx_s, shift_reg[7:1]}; // LSB first → shift in from MSB
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
                    if (baud_cnt == 0) begin
                        if (rx_s) begin         // valid stop bit
                            rx_data  <= shift_reg;
                            rx_valid <= 1'b1;   // pulse for 1 cycle
                        end
                        state <= IDLE;
                    end else
                        baud_cnt <= baud_cnt - 1;
                end
            endcase
        end
    end
endmodule
