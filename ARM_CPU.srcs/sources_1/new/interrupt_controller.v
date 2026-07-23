`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name : interrupt_controller
// Description : Vectored interrupt controller for 8-bit ARM processor.
//
// Designed to collect interrupt events from the existing communication
// peripherals (UART, SPI, I2C, GPIO) and present a single prioritised
// IRQ line to the CPU pipeline.
//
// Interrupt sources (active-HIGH, directly wired from peripherals):
//   IRQ 0 — UART RX complete   (uart_rx_valid pulse)
//   IRQ 1 — UART TX done       (tx_busy falling edge → tx just finished)
//   IRQ 2 — SPI transfer done  (spi_done pulse)
//   IRQ 3 — I2C operation done (i2c_done pulse)
//   IRQ 4 — I2C NACK error     (i2c_ack=1 when i2c_done fires)
//   IRQ 5 — GPIO pin change    (any enabled GPIO input changed value)
//   IRQ 6 — (reserved / user)
//   IRQ 7 — (reserved / user)
//
// All sources are edge-captured into the PENDING register so the CPU
// will not miss one-cycle pulses from the peripherals.
//
// Memory-mapped registers (active when addressed by io_bus):
//   +0  IRQ_ENABLE   (R/W)  — per-source enable mask
//   +1  IRQ_PENDING  (R/W1C)— pending flags (write 1 to clear)
//   +2  IRQ_PRIORITY (R/W)  — bit-packed priority (see below)
//   +3  IRQ_VECTOR   (R)    — vector address for highest-priority pending IRQ
//   +4  IRQ_STATUS   (R)    — raw real-time source status
//   +5  IRQ_ACK      (W)    — write any value to acknowledge (end-of-interrupt)
//
// Priority encoding (IRQ_PRIORITY register, 8 bits):
//   bit [0] = IRQ0 high-priority, bit [1] = IRQ1 high-priority, etc.
//   1 = high priority, 0 = low priority.
//   Among equal-priority sources, lower IRQ number wins.
//
// Vector table:
//   irq_vector = VECTOR_BASE + irq_number
//   Default VECTOR_BASE = 8'h20 (addresses 0x20..0x27 in instruction ROM)
//   The CPU should have ISR entry points at these ROM locations.
//
// CPU interface:
//   irq_out     — active-HIGH interrupt request to CPU
//   irq_vector  — 8-bit vector for the ISR jump address
//   irq_ack_in  — CPU pulses this to acknowledge / end-of-interrupt
//
// Integration:
//   1. io_bus instantiates this module and routes addresses 0xFD..0xFF
//      (or another free slot) to it.
//   2. arm_processor.v connects irq_out to the pipeline to force a
//      branch to irq_vector when irq_out=1.
//////////////////////////////////////////////////////////////////////////////////
module interrupt_controller (
    input  wire       clk,
    input  wire       reset,

    // ── Interrupt source inputs (directly from peripherals) ──
    input  wire       uart_rx_valid,      // IRQ 0: UART byte received
    input  wire       uart_tx_busy,       // Used to detect TX-done edge
    input  wire       spi_done,           // IRQ 2: SPI transfer complete
    input  wire       i2c_done,           // IRQ 3: I2C byte operation done
    input  wire       i2c_ack,            // Sampled with i2c_done for NACK
    input  wire [7:0] gpio_in,            // Current GPIO input pins
    input  wire [7:0] gpio_irq_mask,      // Which GPIO pins can trigger IRQ5

    // ── Reserved / external user interrupt sources ──
    input  wire       ext_irq6,           // IRQ 6 (directly from FPGA pin or tie to 0)
    input  wire       ext_irq7,           // IRQ 7 (directly from FPGA pin or tie to 0)

    // ── CPU register interface (active when selected by io_bus) ──
    input  wire       cs,                 // chip select from io_bus address decode
    input  wire       we,                 // write enable (mem_write && io_sel)
    input  wire [2:0] reg_addr,           // register offset (0..5)
    input  wire [7:0] write_data,         // data from CPU (STR)
    output reg  [7:0] read_data,          // data to CPU (LDR)

    // ── CPU control signals ──
    output wire       irq_out,            // interrupt request to pipeline
    output wire [7:0] irq_vector          // ISR vector address
);

    // ────────────────────────────────────────────────────────────
    // Parameters
    // ────────────────────────────────────────────────────────────
    localparam [7:0] VECTOR_BASE = 8'h20;  // ISR table starts at ROM address 0x20
    localparam NUM_IRQS = 8;

    // Register offsets
    localparam REG_ENABLE   = 3'd0;
    localparam REG_PENDING  = 3'd1;
    localparam REG_PRIORITY = 3'd2;
    localparam REG_VECTOR   = 3'd3;
    localparam REG_STATUS   = 3'd4;
    localparam REG_ACK      = 3'd5;

    // ────────────────────────────────────────────────────────────
    // Internal registers
    // ────────────────────────────────────────────────────────────
    reg [7:0] irq_enable;        // per-source enable mask
    reg [7:0] irq_pending;       // latched pending flags
    reg [7:0] irq_priority_reg;  // 1-bit priority per source (1=high, 0=low)
    reg       irq_active;        // currently servicing an IRQ
    reg [2:0] active_irq_num;    // which IRQ is being serviced

    // ────────────────────────────────────────────────────────────
    // Edge detection for level/pulse sources
    // ────────────────────────────────────────────────────────────
    reg       uart_tx_busy_prev;
    reg [7:0] gpio_in_prev;

    // Derived single-cycle event pulses
    wire uart_tx_done_pulse = uart_tx_busy_prev & ~uart_tx_busy;  // falling edge of tx_busy
    wire gpio_change_pulse  = |((gpio_in ^ gpio_in_prev) & gpio_irq_mask);  // any masked pin changed
    wire i2c_nack_pulse     = i2c_done & i2c_ack;  // NACK detected when i2c_done fires

    // Raw interrupt source vector (active-HIGH, directly from peripherals)
    wire [7:0] irq_sources = {
        ext_irq7,           // IRQ 7
        ext_irq6,           // IRQ 6
        gpio_change_pulse,  // IRQ 5
        i2c_nack_pulse,     // IRQ 4
        i2c_done,           // IRQ 3
        spi_done,           // IRQ 2
        uart_tx_done_pulse, // IRQ 1
        uart_rx_valid       // IRQ 0
    };

    // ────────────────────────────────────────────────────────────
    // Priority resolver
    // Scans enabled & pending IRQs. High-priority (bit=1) sources
    // are checked first; within equal priority, lower IRQ# wins.
    // ────────────────────────────────────────────────────────────
    reg       valid_irq;
    reg [2:0] best_irq;

    always @(*) begin
        valid_irq = 1'b0;
        best_irq  = 3'd0;

        // Pass 1 — scan high-priority sources (priority bit = 1)
        begin : hi_scan
            integer i;
            for (i = 0; i < NUM_IRQS; i = i + 1) begin
                if (irq_pending[i] && irq_enable[i] && irq_priority_reg[i] && !valid_irq) begin
                    valid_irq = 1'b1;
                    best_irq  = i[2:0];
                end
            end
        end

        // Pass 2 — if no high-priority match, scan low-priority (priority bit = 0)
        if (!valid_irq) begin : lo_scan
            integer i;
            for (i = 0; i < NUM_IRQS; i = i + 1) begin
                if (irq_pending[i] && irq_enable[i] && !irq_priority_reg[i] && !valid_irq) begin
                    valid_irq = 1'b1;
                    best_irq  = i[2:0];
                end
            end
        end
    end

    // ────────────────────────────────────────────────────────────
    // Outputs to CPU
    // ────────────────────────────────────────────────────────────
    assign irq_out    = valid_irq & ~irq_active;   // Don't re-assert while servicing
    assign irq_vector = VECTOR_BASE + {5'b00000, best_irq};

    // ────────────────────────────────────────────────────────────
    // Sequential logic — edge detectors + pending capture + register writes
    // ────────────────────────────────────────────────────────────
    always @(posedge clk) begin
        if (reset) begin
            irq_enable       <= 8'h00;  // All interrupts disabled after reset
            irq_pending      <= 8'h00;
            irq_priority_reg <= 8'h00;  // All low-priority by default
            irq_active       <= 1'b0;
            active_irq_num   <= 3'd0;
            uart_tx_busy_prev<= 1'b0;
            gpio_in_prev     <= 8'h00;
        end else begin
            // ── Edge detectors (update every cycle) ──
            uart_tx_busy_prev <= uart_tx_busy;
            gpio_in_prev      <= gpio_in;

            // ── Latch new interrupts into pending ──
            // OR in any new source pulses (only for enabled sources)
            irq_pending <= irq_pending | (irq_sources & irq_enable);

            // ── CPU register writes ──
            if (cs && we) begin
                case (reg_addr)
                    REG_ENABLE: begin
                        irq_enable <= write_data;
                    end

                    REG_PENDING: begin
                        // Write-1-to-clear: CPU writes 1 to clear specific pending bits
                        irq_pending <= irq_pending & ~write_data;
                    end

                    REG_PRIORITY: begin
                        irq_priority_reg <= write_data;
                    end

                    REG_ACK: begin
                        // End-of-interrupt: CPU signals it has finished the ISR
                        if (irq_active) begin
                            irq_active     <= 1'b0;
                            // Also clear the pending bit for the serviced IRQ
                            irq_pending[active_irq_num] <= 1'b0;
                        end
                    end

                    default: ; // No action for read-only registers
                endcase
            end

            // ── Auto-acknowledge: when CPU takes the interrupt ──
            // The pipeline should pulse irq_ack or we detect irq_out was high
            // and the pipeline jumped. For simplicity, we latch when io_bus
            // does NOT write ACK — the CPU should write ACK at end of ISR.
            // If irq_out is asserted and pipeline will branch:
            if (irq_out && !irq_active) begin
                // This will be driven by the pipeline's interrupt-taken signal
                // For now: pipeline must explicitly write REG_ACK
                // Mark as active to prevent re-triggering
                irq_active     <= 1'b1;
                active_irq_num <= best_irq;
                // Clear pending for this IRQ (servicing now)
                irq_pending[best_irq] <= 1'b0;
            end
        end
    end

    // ────────────────────────────────────────────────────────────
    // Register read logic (active when cs=1, we=0)
    // ────────────────────────────────────────────────────────────
    always @(*) begin
        read_data = 8'h00;
        if (cs && !we) begin
            case (reg_addr)
                REG_ENABLE:   read_data = irq_enable;
                REG_PENDING:  read_data = irq_pending;
                REG_PRIORITY: read_data = irq_priority_reg;
                REG_VECTOR:   read_data = irq_vector;
                REG_STATUS:   read_data = irq_sources;  // Real-time raw status
                REG_ACK:      read_data = {4'b0, irq_active, active_irq_num};
                default:      read_data = 8'h00;
            endcase
        end
    end

endmodule
