`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name : spi_master
// Description : SPI master, mode 0 (CPOL=0, CPHA=0), 8-bit transfers.
//
// Mode 0: SCK idles LOW. Data sampled on rising edge, shifted on falling edge.
//
// Operation:
//   CPU writes to SPI_DATA address (0xF2) → triggers a transfer.
//   spi_busy=1 while transferring. When done, rx_data holds the received byte
//   and spi_done pulses for 1 cycle.
//
// Clock divider:
//   sck_div = clk_freq / (2 * spi_freq)
//   Example: 50MHz clock, 1MHz SPI → sck_div = 25
//
// Pins:
//   mosi — master out, slave in
//   miso — master in, slave out
//   sck  — serial clock
//   cs_n — chip select (active LOW)
//////////////////////////////////////////////////////////////////////////////////
module spi_master #(
    parameter SCK_DIV = 25      // 50MHz / (2*1MHz)
)(
    input  wire       clk,
    input  wire       reset,
    input  wire       start,       // pulse 1 cycle to begin transfer
    input  wire [7:0] tx_data,     // byte to send (MOSI)
    output reg  [7:0] rx_data,     // byte received (MISO)
    output reg        spi_busy,
    output reg        spi_done,    // pulses 1 cycle when transfer complete
    // SPI pins
    output reg        sck,
    output reg        mosi,
    input  wire       miso,
    output reg        cs_n
);
    reg [7:0]  shift_tx;    // transmit shift register
    reg [7:0]  shift_rx;    // receive shift register
    reg [3:0]  bit_cnt;     // counts bits (0..7)
    reg [7:0]  clk_cnt;     // SCK divider counter
    reg        phase;       // 0=high-half, 1=low-half of SCK period

    always @(posedge clk) begin
        if (reset) begin
            sck      <= 0;
            mosi     <= 0;
            cs_n     <= 1;
            spi_busy <= 0;
            spi_done <= 0;
            shift_tx <= 0;
            shift_rx <= 0;
            bit_cnt  <= 0;
            clk_cnt  <= 0;
            phase    <= 0;
            rx_data  <= 0;
        end else begin
            spi_done <= 0; // default

            if (!spi_busy) begin
                sck  <= 0;
                cs_n <= 1;
                if (start) begin
                    shift_tx <= tx_data;
                    bit_cnt  <= 0;
                    clk_cnt  <= SCK_DIV - 1;
                    phase    <= 0;
                    cs_n     <= 0;  // assert CS
                    spi_busy <= 1;
                    mosi     <= tx_data[7]; // MSB first
                end
            end else begin
                if (clk_cnt == 0) begin
                    clk_cnt <= SCK_DIV - 1;
                    phase   <= ~phase;

                    if (!phase) begin
                        // Rising edge — sample MISO
                        sck      <= 1;
                        shift_rx <= {shift_rx[6:0], miso};
                    end else begin
                        // Falling edge — shift out next MOSI bit
                        sck <= 0;
                        if (bit_cnt == 7) begin
                            // Transfer complete
                            cs_n     <= 1;
                            spi_busy <= 0;
                            spi_done <= 1;
                            rx_data  <= {shift_rx[6:0], miso};
                        end else begin
                            bit_cnt  <= bit_cnt + 1;
                            shift_tx <= {shift_tx[6:0], 1'b0};
                            mosi     <= shift_tx[6]; // next bit
                        end
                    end
                end else
                    clk_cnt <= clk_cnt - 1;
            end
        end
    end
endmodule
