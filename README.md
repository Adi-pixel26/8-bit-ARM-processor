# 5-Stage Pipelined 8-Bit ARM-Like Processor

This repository contains the complete Verilog source code and Vivado project for a custom 5-stage pipelined 8-bit processor inspired by the ARM architecture. 

It is designed to demonstrate advanced computer architecture concepts including data hazard resolution, instruction stalling, operand forwarding, and branch resolution within a hardware pipeline.

---

## Schematic & Architecture Overview
![ARM CPU Schematic](schematic.png)

The processor executes a custom 16-bit instruction set, operating on an 8-bit datapath. The pipeline is strictly divided into the classic 5 stages to maximize instruction throughput:

1. **IF (Instruction Fetch):** Retrieves the 16-bit instruction from Instruction Memory (ROM) using the Program Counter (PC).
2. **ID (Instruction Decode):** Decodes the opcode, fetches operands from the Register File, and generates control signals.
3. **EX (Execute):** Performs ALU operations and resolves branch conditions.
4. **MEM (Memory Access):** Interfaces with SRAM for Load (LDR) and Store (STR) instructions.
5. **WB (Writeback):** Writes ALU results or Memory read data back to the destination register.

---

## Technical Specifications

### Instruction Format
The CPU uses a uniform 16-bit instruction encoding:
`[15:12] Opcode | [11:9] Rd | [8:6] Rs1 | [5:3] Rs2 | [2:0] Imm3`

### Hazard Handling & Forwarding
To maintain pipeline efficiency without stalling on every data dependency, the architecture includes dedicated hazard logic:
* **Forwarding Unit (`forward_unit.v`):** Detects Read-After-Write (RAW) data hazards and bypasses data directly from the EX/MEM or MEM/WB pipeline registers into the ALU inputs, saving clock cycles.
* **Hazard Detection Unit (`hazard_unit.v`):** Detects Load-Use hazards (where forwarding cannot resolve the timing issue) and injects a pipeline stall (NOP) to allow the data memory to catch up.

### Peripherals & Interconnects
The CPU is highly capable and interfaces with a custom IO Bus containing several synthesized peripheral controllers:
* **Interrupt Controller:** Manages asynchronous hardware interrupts.
* **SPI & I2C Masters:** For interfacing with external sensors or EEPROMs.
* **UART (Rx/Tx):** Full-duplex serial communication.
* **SRAM Controller:** 8-bit Data Memory interface.

---

## Project Structure

* **`arm_processor.v`**: The Top-Level module instantiating the pipeline and control logic.
* **`fetch_stage.v` & `program_counter.v`**: Manages the IF stage.
* **`control_unit.v`**: Decodes instructions into active high/low control signals.
* **`register_file.v`**: General purpose CPU registers.
* **`arm.v`**: The Arithmetic Logic Unit (ALU).
* **Pipeline Registers**: `if_id_reg.v`, `id_ex_reg.v`, `ex_mem_reg.v`, `mem_wb_reg.v`.
* **Testbenches**: `armprocessor_tb.v` to simulate and verify the entire pipeline.
* **Vivado Project**: `ARM_CPU.xpr` (Open directly in Xilinx Vivado).

---

## Getting Started

1. Clone this repository.
2. Open **Xilinx Vivado**.
3. Click **Open Project** and select `ARM_CPU.xpr`.
4. Run the simulation using `armprocessor_tb.v` to view the pipeline waveforms, or synthesize the design for your target FPGA.
