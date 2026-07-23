`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name : io_bus
// Description : Memory-mapped IO bus connecting CPU to peripherals.
//
// The CPU accesses peripherals exactly like SRAM — using LDR/STR instructions
// to specific addresses. The io_bus intercepts addresses in the IO range
// (0xF0..0xFF) and routes them to the correct peripheral.
//
// Memory map:
//   0xF0 — UART_TX_DATA  (write) : send byte over UART
//   0xF1 — UART_RX_DATA  (read)  : read received UART byte
//   0xF2 — UART_STATUS   (read)  : bit0=tx_busy, bit1=rx_valid
//   0xF3 — SPI_DATA      (write) : trigger SPI transfer with this byte
//   0xF4 — SPI_RX        (read)  : last byte received over SPI
//   0xF5 — SPI_STATUS    (read)  : bit0=spi_busy, bit1=spi_done
//   0xF6 — I2C_ADDR      (write) : set I2C device address + R/W bit
//   0xF7 — I2C_DATA      (write/read) : byte to write / byte received
//   0xF8 — I2C_CTRL      (write) : bit0=start, bit1=stop, bit2=read_byte
//   0xF9 — I2C_STATUS    (read)  : bit0=busy, bit1=ack, bit2=done
//   0xFA — GPIO_OUT      (write) : drive 8 GPIO output pins
//   0xFB — GPIO_IN       (read)  : read 8 GPIO input pins
//   0xFC — GPIO_DIR      (write) : 1=output, 0=input per pin
//
// Integration:
//   io_bus sits between the CPU datapath and SRAM.
//   When address >= 0xF0, io_bus handles the access.
//   When address < 0xF0, SRAM handles it normally.
//   The cpu_read_data mux in arm_processor.v selects between sram and io_bus.
//////////////////////////////////////////////////////////////////////////////////
module io_bus #(
    parameter BAUD_DIV = 434,   // UART baud divider
    parameter SCK_DIV  = 25,    // SPI clock divider
    parameter I2C_DIV  = 125    // I2C clock divider
)(
    input  wire       clk,
    input  wire       reset,

    // CPU interface
    input  wire [7:0] address,      // from ALU result (effective address)
    input  wire [7:0] write_data,   // data to write (from rs2)
    input  wire       mem_write,    // CPU is doing a STR
    input  wire       mem_read,     // CPU is doing a LDR
    output reg  [7:0] read_data,    // data returned to CPU

    // UART pins
    output wire       uart_tx,
    input  wire       uart_rx,

    // SPI pins
    output wire       spi_sck,
    output wire       spi_mosi,
    input  wire       spi_miso,
    output wire       spi_cs_n,

    // I2C pins
    output wire       i2c_scl,
    output wire       i2c_sda_out,
    input  wire       i2c_sda_in,

    // GPIO
    output reg  [7:0] gpio_out,
    input  wire [7:0] gpio_in,
    output reg  [7:0] gpio_dir
);
    // =========================================================
    // IO address decode — only active when address >= 0xF0
    // =========================================================
    wire io_sel = (address >= 8'hF0);

    // =========================================================
    // UART
    // =========================================================
    reg        uart_tx_valid;
    reg  [7:0] uart_tx_data;
    wire       uart_tx_busy;
    reg  [7:0] uart_rx_latch;   // latched received byte
    wire       uart_rx_valid;
    wire [7:0] uart_rx_data_w;

    uart_tx #(.BAUD_DIV(BAUD_DIV)) U_TX (
        .clk     (clk),
        .reset   (reset),
        .tx_valid(uart_tx_valid),
        .tx_data (uart_tx_data),
        .tx_busy (uart_tx_busy),
        .tx      (uart_tx)
    );

    uart_rx #(.BAUD_DIV(BAUD_DIV)) U_RX (
        .clk     (clk),
        .reset   (reset),
        .rx      (uart_rx),
        .rx_valid(uart_rx_valid),
        .rx_data (uart_rx_data_w)
    );

    // Latch received byte when rx_valid fires
    always @(posedge clk) begin
        if (reset)
            uart_rx_latch <= 8'h00;
        else if (uart_rx_valid)
            uart_rx_latch <= uart_rx_data_w;
    end

    // =========================================================
    // SPI
    // =========================================================
    reg        spi_start;
    reg  [7:0] spi_tx_data;
    wire [7:0] spi_rx_data;
    wire       spi_busy, spi_done;

    spi_master #(.SCK_DIV(SCK_DIV)) U_SPI (
        .clk     (clk),
        .reset   (reset),
        .start   (spi_start),
        .tx_data (spi_tx_data),
        .rx_data (spi_rx_data),
        .spi_busy(spi_busy),
        .spi_done(spi_done),
        .sck     (spi_sck),
        .mosi    (spi_mosi),
        .miso    (spi_miso),
        .cs_n    (spi_cs_n)
    );

    // =========================================================
    // I2C
    // =========================================================
    reg        i2c_start_pulse, i2c_stop_pulse, i2c_read_pulse;
    reg  [7:0] i2c_addr_reg, i2c_wr_data;
    wire [7:0] i2c_rd_data;
    wire       i2c_busy, i2c_ack_flag, i2c_done;
    wire       i2c_scl_w, i2c_sda_w;

    i2c_master #(.CLK_DIV(I2C_DIV)) U_I2C (
        .clk         (clk),
        .reset       (reset),
        .i2c_addr_in (i2c_addr_reg),
        .i2c_data_in (i2c_wr_data),
        .i2c_start   (i2c_start_pulse),
        .i2c_stop    (i2c_stop_pulse),
        .i2c_read    (i2c_read_pulse),
        .i2c_data_out(i2c_rd_data),
        .i2c_busy    (i2c_busy),
        .i2c_ack     (i2c_ack_flag),
        .i2c_done    (i2c_done),
        .scl_out     (i2c_scl_w),
        .sda_out     (i2c_sda_w),
        .sda_in      (i2c_sda_in)
    );

    assign i2c_scl     = i2c_scl_w;
    assign i2c_sda_out = i2c_sda_w;

    // =========================================================
    // WRITE handler — CPU STR to IO address
    // =========================================================
    always @(posedge clk) begin
        if (reset) begin
            uart_tx_valid    <= 0;
            uart_tx_data     <= 0;
            spi_start        <= 0;
            spi_tx_data      <= 0;
            i2c_start_pulse  <= 0;
            i2c_stop_pulse   <= 0;
            i2c_read_pulse   <= 0;
            i2c_addr_reg     <= 0;
            i2c_wr_data      <= 0;
            gpio_out         <= 0;
            gpio_dir         <= 8'hFF;  // default all outputs
        end else begin
            // Clear pulse signals every cycle
            uart_tx_valid   <= 0;
            spi_start       <= 0;
            i2c_start_pulse <= 0;
            i2c_stop_pulse  <= 0;
            i2c_read_pulse  <= 0;

            if (io_sel && mem_write) begin
                case (address)
                    8'hF0: begin    // UART TX
                        uart_tx_data  <= write_data;
                        uart_tx_valid <= 1;
                    end
                    8'hF3: begin    // SPI — trigger transfer
                        spi_tx_data <= write_data;
                        spi_start   <= 1;
                    end
                    8'hF6: begin    // I2C address
                        i2c_addr_reg <= write_data;
                    end
                    8'hF7: begin    // I2C write data
                        i2c_wr_data <= write_data;
                    end
                    8'hF8: begin    // I2C control
                        i2c_start_pulse <= write_data[0];
                        i2c_stop_pulse  <= write_data[1];
                        i2c_read_pulse  <= write_data[2];
                    end
                    8'hFA: begin    // GPIO output
                        gpio_out <= write_data;
                    end
                    8'hFC: begin    // GPIO direction
                        gpio_dir <= write_data;
                    end
                    default: ;
                endcase
            end
        end
    end

    // =========================================================
    // READ handler — CPU LDR from IO address
    // =========================================================
    always @(*) begin
        read_data = 8'h00;
        if (io_sel && mem_read) begin
            case (address)
                8'hF1: read_data = uart_rx_latch;
                8'hF2: read_data = {6'b0, uart_rx_valid, uart_tx_busy};
                8'hF4: read_data = spi_rx_data;
                8'hF5: read_data = {6'b0, spi_done, spi_busy};
                8'hF7: read_data = i2c_rd_data;
                8'hF9: read_data = {5'b0, i2c_done, i2c_ack_flag, i2c_busy};
                8'hFB: read_data = gpio_in;
                default: read_data = 8'h00;
            endcase
        end
    end

endmodule
