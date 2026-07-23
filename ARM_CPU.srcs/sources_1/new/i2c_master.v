`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name : i2c_master
// Description : I2C master controller, 100kHz standard mode.
//
// Supports:
//   - Write transaction: START + addr + W + data bytes + STOP
//   - Read  transaction: START + addr + R + repeated START + data bytes + STOP
//
// Operation (simplified for CPU use):
//   CPU writes to I2C_ADDR  (0xF4): set 7-bit device address + R/W bit
//   CPU writes to I2C_DATA  (0xF5): byte to send (write mode)
//   CPU writes to I2C_CTRL  (0xF6): bit0=start, bit1=stop, bit2=read_byte
//   CPU reads  from I2C_DATA (0xF5): received byte (read mode)
//   i2c_busy=1 while bus transaction in progress.
//   i2c_ack=0 means slave ACKed (success), i2c_ack=1 means NACK.
//
// Clock:
//   clk_div = clk_freq / (4 * i2c_freq)
//   4 phases per SCL period. Example: 50MHz, 100kHz → clk_div = 125
//
// Pins: sda (open-drain), scl (open-drain)
// For FPGA: drive low or release (tri-state/pullup handles high).
// In simulation: sda_out=0 drives low, sda_out=1 releases (pulled high).
//////////////////////////////////////////////////////////////////////////////////
module i2c_master #(
    parameter CLK_DIV = 125     // 50MHz / (4 * 100kHz)
)(
    input  wire       clk,
    input  wire       reset,

    // CPU interface
    input  wire [7:0] i2c_addr_in,  // {7-bit addr, R/W}
    input  wire [7:0] i2c_data_in,  // byte to write
    input  wire       i2c_start,    // pulse: begin transaction
    input  wire       i2c_stop,     // pulse: send stop condition
    input  wire       i2c_read,     // pulse: read one byte
    output reg  [7:0] i2c_data_out, // received byte
    output reg        i2c_busy,
    output reg        i2c_ack,      // 0=ACK, 1=NACK
    output reg        i2c_done,     // pulses when byte operation completes

    // I2C bus (open-drain — drive low or release)
    output reg        scl_out,      // 0=drive low, 1=release (pulled high)
    output reg        sda_out,      // 0=drive low, 1=release (pulled high)
    input  wire       sda_in        // read SDA (for ACK sampling)
);
    // State machine
    localparam IDLE      = 4'd0;
    localparam START1    = 4'd1;  // SDA low while SCL high
    localparam START2    = 4'd2;  // SCL goes low
    localparam SEND_BIT  = 4'd3;  // drive SDA, SCL low
    localparam SCL_HIGH  = 4'd4;  // SCL goes high
    localparam SCL_LOW   = 4'd5;  // SCL goes low (end of bit)
    localparam ACK_READ  = 4'd6;  // release SDA, SCL high → read ACK
    localparam ACK_LOW   = 4'd7;  // SCL low after ACK
    localparam STOP1     = 4'd8;  // SDA low while SCL goes high
    localparam STOP2     = 4'd9;  // SDA high = stop

    reg [3:0]  state;
    reg [7:0]  clk_cnt;
    reg [7:0]  shift_reg;
    reg [3:0]  bit_cnt;
    reg        rw_mode;     // 0=write, 1=read

    always @(posedge clk) begin
        if (reset) begin
            state        <= IDLE;
            scl_out      <= 1;
            sda_out      <= 1;
            i2c_busy     <= 0;
            i2c_ack      <= 0;
            i2c_done     <= 0;
            i2c_data_out <= 0;
            clk_cnt      <= 0;
            shift_reg    <= 0;
            bit_cnt      <= 0;
            rw_mode      <= 0;
        end else begin
            i2c_done <= 0;

            if (clk_cnt != 0) begin
                clk_cnt <= clk_cnt - 1;
            end else begin
                case (state)
                    IDLE: begin
                        scl_out  <= 1;
                        sda_out  <= 1;
                        i2c_busy <= 0;
                        if (i2c_start) begin
                            shift_reg <= i2c_addr_in;
                            rw_mode   <= i2c_addr_in[0];
                            bit_cnt   <= 7;
                            i2c_busy  <= 1;
                            clk_cnt   <= CLK_DIV - 1;
                            state     <= START1;
                        end
                    end

                    START1: begin
                        // SDA goes low while SCL is high
                        sda_out <= 0;
                        clk_cnt <= CLK_DIV - 1;
                        state   <= START2;
                    end

                    START2: begin
                        // SCL goes low
                        scl_out <= 0;
                        clk_cnt <= CLK_DIV - 1;
                        state   <= SEND_BIT;
                    end

                    SEND_BIT: begin
                        sda_out <= shift_reg[7]; // MSB first
                        clk_cnt <= CLK_DIV - 1;
                        state   <= SCL_HIGH;
                    end

                    SCL_HIGH: begin
                        scl_out <= 1;
                        clk_cnt <= CLK_DIV - 1;
                        state   <= SCL_LOW;
                    end

                    SCL_LOW: begin
                        scl_out  <= 0;
                        shift_reg<= {shift_reg[6:0], 1'b0};
                        clk_cnt  <= CLK_DIV - 1;
                        if (bit_cnt == 0) begin
                            state <= ACK_READ;
                        end else begin
                            bit_cnt <= bit_cnt - 1;
                            state   <= SEND_BIT;
                        end
                    end

                    ACK_READ: begin
                        // Release SDA, raise SCL, sample ACK
                        sda_out  <= 1;
                        scl_out  <= 1;
                        i2c_ack  <= sda_in; // 0=ACK, 1=NACK
                        clk_cnt  <= CLK_DIV - 1;
                        state    <= ACK_LOW;
                    end

                    ACK_LOW: begin
                        scl_out  <= 0;
                        i2c_done <= 1;
                        clk_cnt  <= CLK_DIV - 1;
                        if (i2c_stop) begin
                            state <= STOP1;
                        end else if (i2c_read) begin
                            // Set up to receive a byte
                            shift_reg <= 0;
                            bit_cnt   <= 7;
                            sda_out   <= 1; // release SDA for reading
                            state     <= SCL_HIGH; // reuse SCL_HIGH for read bits
                        end else begin
                            // Next write byte
                            shift_reg <= i2c_data_in;
                            bit_cnt   <= 7;
                            state     <= SEND_BIT;
                        end
                    end

                    STOP1: begin
                        sda_out <= 0;
                        scl_out <= 1;
                        clk_cnt <= CLK_DIV - 1;
                        state   <= STOP2;
                    end

                    STOP2: begin
                        sda_out  <= 1; // STOP: SDA rises while SCL high
                        i2c_busy <= 0;
                        state    <= IDLE;
                    end

                    default: state <= IDLE;
                endcase
            end
        end
    end
endmodule
