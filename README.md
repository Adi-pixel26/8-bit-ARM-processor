# 5-Stage Pipelined 8-Bit ARM-Like Processor

This repository contains the complete Verilog source code and Vivado project for a custom 5-stage pipelined 8-bit processor inspired by the ARM architecture. 

It is designed to demonstrate advanced computer architecture concepts, including data hazard resolution, instruction stalling, operand forwarding, and branch resolution within a hardware pipeline.

---

## Schematic & Architecture Overview
![ARM CPU Schematic](schematic.png)

The processor executes a custom 16-bit instruction set, operating on an 8-bit datapath. The pipeline is strictly divided into the classic 5 stages to maximize instruction throughput:

1. **IF (Instruction Fetch):** Retrieves the 16-bit instruction from Instruction Memory (ROM) using the Program Counter (PC). Incorporates branch target overriding.
2. **ID (Instruction Decode):** Decodes the opcode via the `control_unit.v`, fetches operands from the dual-port `register_file.v`, and sets up execution flags.
3. **EX (Execute):** The `arm.v` ALU performs arithmetic/logic operations. Branch conditions (Zero/Carry flags) are resolved in this stage to minimize branch penalty.
4. **MEM (Memory Access):** Interfaces with SRAM (`datamem.v`) for Load (`LDR`) and Store (`STR`) instructions using precise Chip Select (`sram_cs`), Output Enable (`sram_oe`), and Write Enable (`sram_we`) signalling.
5. **WB (Writeback):** Writes ALU results or Memory read data back to the destination register.

---

## Instruction Set Architecture (ISA)

The CPU uses a uniform 16-bit instruction encoding:
`[15:12] Opcode | [11:9] Rd | [8:6] Rs1 | [5:3] Rs2 | [2:0] Imm3`

### Supported Opcodes (4-bit)
| Opcode | Mnemonic | Operation | Description |
| :---: | :---: | :--- | :--- |
| `0000` | **ADD** | `Rd = Rs1 + Rs2` | Integer Addition |
| `0001` | **MOV** | `Rd = Imm3` | Move Immediate |
| `0010` | **SUB** | `Rd = Rs1 - Rs2` | Integer Subtraction |
| `0011` | **AND** | `Rd = Rs1 & Rs2` | Bitwise AND |
| `0100` | **OR** | `Rd = Rs1 \| Rs2` | Bitwise OR |
| `0101` | **XOR** | `Rd = Rs1 ^ Rs2` | Bitwise XOR |
| `0110` | **LDR** | `Rd = SRAM[Rs1 + Imm3]` | Load Data from SRAM |
| `0111` | **STR** | `SRAM[Rs1 + Imm3] = Rs2` | Store Data to SRAM |
| `1000` | **BEQ** | `PC = PC + Imm3` | Branch if Equal (Zero Flag = 1) |
| `1001` | **BNE** | `PC = PC + Imm3` | Branch if Not Equal (Zero Flag = 0) |
| `1010` | **BRA** | `PC = PC + Imm3` | Unconditional Branch |
| `1011` | **LSL** | `Rd = Rs1 << 1` | Logical Shift Left |
| `1100` | **LSR** | `Rd = Rs1 >> 1` | Logical Shift Right |
| `1101` | **NOT** | `Rd = ~Rs1` | Bitwise NOT (Utilizes `inv_a` hardware flag) |
| `1110` | **CMP** | `Rs1 - Rs2` | Sets Zero/Carry flags; no writeback |

---

## Hazard Handling & Forwarding

To maintain pipeline efficiency without stalling on every data dependency, the architecture includes dedicated hardware logic for hazard resolution:

* **Forwarding Unit (`forward_unit.v`):** 
  Detects Read-After-Write (RAW) data hazards. If an instruction in the EX stage requires data currently being computed in the MEM or WB stages, the Forwarding Unit overrides the ALU inputs, bypassing the data directly from the `ex_mem_reg` or `mem_wb_reg`. This prevents unnecessary stalls.
* **Hazard Detection Unit (`hazard_unit.v`):** 
  Detects Load-Use hazards (e.g., when an `ADD` instruction immediately follows an `LDR` instruction targeting the same register). Because SRAM read data isn't available until the end of the MEM stage, forwarding alone cannot resolve this. The Hazard Unit injects a pipeline stall (NOP) into the ID/EX register and halts the PC to allow the data memory to catch up.

---

## Peripherals & Interconnects

The CPU is highly capable and interfaces with a custom IO Bus containing several synthesized peripheral controllers designed in Verilog:
* **Interrupt Controller:** Manages asynchronous hardware interrupts, safely halting the pipeline and vectoring the PC.
* **SPI & I2C Masters:** Core serial protocols for interfacing with external sensors, displays, or EEPROMs.
* **UART (Rx/Tx):** Full-duplex serial communication for console debugging.
* **SRAM Controller:** Dedicated 8-bit Data Memory interface.

---

## Project Structure

* **`arm_processor.v`**: The Top-Level module instantiating the pipeline and control logic.
* **`fetch_stage.v` & `program_counter.v`**: Manages the IF stage.
* **`control_unit.v`**: Hardwired instruction decoder translating opcodes into active control signals.
* **`register_file.v`**: General purpose CPU registers (Dual-read, Single-write).
* **`arm.v`**: The Arithmetic Logic Unit (ALU).
* **Pipeline Registers**: `if_id_reg.v`, `id_ex_reg.v`, `ex_mem_reg.v`, `mem_wb_reg.v`.
* **Testbenches**: `armprocessor_tb.v` to simulate and verify the entire pipeline logic and hazard resolution.
* **Vivado Project**: `ARM_CPU.xpr` (Open directly in Xilinx Vivado).

---

## Getting Started

1. Clone this repository.
2. Open **Xilinx Vivado**.
3. Click **Open Project** and select `ARM_CPU.xpr`.
4. Run the simulation using `armprocessor_tb.v` to view the pipeline waveforms, or synthesize the design for your target FPGA architecture.
