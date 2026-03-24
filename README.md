# SIMD Vector Processing Unit

## What This Is
A custom pipelined SIMD (Single Instruction Multiple Data) vector processing unit written from scratch in SystemVerilog. This is a portfolio project to show microarchitecture design skills. It is NOT a general purpose CPU — it is a specialized vector compute engine, similar in concept to things like ARM NEON or RISC-V vector extensions.

The whole point of this design is to process 8 elements in parallel using INT8 (signed 8-bit integers), which is a data type heavily used in ML inference hardware.

---

## Architecture Overview

### Data Path
- **Data type:** INT8 (signed 8-bit)
- **Vector width:** 64 bits per register (holds 8 INT8 elements)
- **Slices:** 8 parallel compute slices — each one handles one element independently
- I call them "slices" instead of "lanes," personal naming choice

### Register File
- 16 vector registers (v0 to v15)
- Each register is 64 bits wide
- 3 read ports and 1 write port
- 3 read ports are needed because VMAC has to read src1, src2, AND the destination register all at the same time
- Synchronous reads

### Memory (SRAM)
- 256 bytes total
- 32 locations, each 64 bits wide (matches vector register width)
- 5-bit address space
- Reads happen every cycle, writes are gated by enable
- Implemented as a register array in RTL

### Pipeline
4 stages, uniform latency:

| Stage | What It Does |
|-------|-------------|
| Stage 1 | Decode — break the 16-bit instruction into fields and generate control signals |
| Stage 2 | Operand Fetch and Sparsity Check |
| Stage 3 | Execute — all 8 slices compute in parallel |
| Stage 4 | Reduction (VDOT only) and Writeback |

---

## Instruction Set (7 Instructions)

| Opcode | Instruction | What It Does |
|--------|------------|--------------|
| 000 | VADD | Element-wise addition |
| 001 | VMUL | Element-wise multiplication (sparsity aware) |
| 010 | VMAC | Multiply-accumulate (sparsity aware) |
| 011 | VDOT | Dot product with reduction tree (sparsity aware) |
| 100 | VRELU | ReLU activation — clamps negatives to zero |
| 101 | VLOAD | Load 8 INT8 values from SRAM into a vector register |
| 110 | VSTORE | Write a vector register to SRAM |
| 111 | RESERVED | — |

### ISA Encoding (16-bit fixed width)

[opcode(3) | vdst(4) | vsrc1(4) | vsrc2(4) | MBZ(1)]

### Special Cases
- **VLOAD:** vsrc2 unused (set to 0), vsrc1 holds memory address
- **VSTORE:** vdst unused (set to 0), vsrc1 holds memory address, vsrc2 holds data register
- **VRELU:** vsrc2 unused

---

## Control Signals

9 control signals generated combinationally from the opcode:

| Instruction | wr | sram | sram_f | red | spar | wb_sel | alu | v2 | r3 |
|-------------|-----|------|--------|-----|------|--------|-----|-----|-----|
| VADD | 1 | 0 | 0 | 0 | 0 | 01 | 1 | 1 | 0 |
| VMUL | 1 | 0 | 0 | 0 | 1 | 01 | 1 | 1 | 0 |
| VMAC | 1 | 0 | 0 | 0 | 1 | 01 | 1 | 1 | 1 |
| VDOT | 1 | 0 | 0 | 1 | 1 | 10 | 1 | 1 | 0 |
| VRELU | 1 | 0 | 0 | 0 | 0 | 01 | 1 | 0 | 0 |
| VLOAD | 1 | 1 | 0 | 0 | 0 | 00 | 0 | 0 | 0 |
| VSTORE | 0 | 1 | 1 | 0 | 0 | 00 | 0 | 1 | 0 |
| default | 0 | 0 | 0 | 0 | 0 | 00 | 0 | 0 | 0 |

---

## Sparsity Aware Execution
- Applies to VMUL, VMAC, and VDOT only
- If either operand in a slice is zero, that slice gets skipped
- Generates an 8-bit bitmask (1 = active, 0 = skip)
- The bitmask is ANDed with the ALU enable to gate each slice individually

---

## Reduction Tree (VDOT Only)
- Takes 8 slice multiplication results (each 16-bit)
- Sums them down in 3 levels of parallel additions
  - Level 1: 8 to 4 partial sums (17 bits)
  - Level 2: 4 to 2 partial sums (18 bits)
  - Level 3: 2 to 1 final result (19 bits, zero extended to 32 bits)
- Purely combinational (no clock)
- Verified: 8 x 16129 = 129032

---

## Writeback Path
Three possible sources write back to the register file through a mux:

| writeback_sel | Source | Used By |
|---------------|--------|---------|
| 00 | SRAM output | VLOAD |
| 01 | ALU (packed 8 slices) | VADD, VMUL, VMAC, VRELU |
| 10 | Reduction tree | VDOT |

---

## Top Level Interface

module simd (
    input  logic        clk,
    input  logic        rst,
    input  logic [15:0] instruction,
    output logic [63:0] result,
    output logic [31:0] scalar,
    output logic        valid
);

- Instructions are driven externally (no instruction memory or program counter inside)
- result is the 64-bit vector writeback
- scalar is the 32-bit VDOT dot product output
- valid is high when the output is meaningful (driven by write_reg_en)

---

## File Structure

SIMD/
├── rtl/
│   ├── simd.sv        — DONE
│   ├── control.sv         — DONE
│   ├── registers.sv       — DONE
│   ├── slice.sv           — DONE
│   ├── reductiontree.sv   — DONE
│   ├── sparsity.sv        — DONE
│   ├── sram.sv            — DONE
│   └── pmu.sv        — not started
├── tb/
│   └── simd_tb.sv         — in progress
├── assertions/
│   └── properties.sv — not started
├── python/
│   ├── golden.py    — not started
│   ├── vectorgen.py— not started
│   └── analysis.py        — not started
├── docs/
│   ├── architecture.md
│   └── diagrams/
└── README.md

---

## Completed RTL Modules

### control.sv
Purely combinational control signal generator. Takes a 3-bit opcode and outputs all 9 control signals through an always_comb case statement.

### registers.sv
16-entry vector register file. 64 bits per register. 3 synchronous read ports, 1 write port. Write gated by enable. All registers reset to zero.

### sram.sv
32-location memory, 64 bits per location. Write gated by enable, reads happen every cycle. Resets to all zeros.

### slice.sv
Single compute slice. Handles VADD, VMUL, VMAC, VDOT, and VRELU for one 8-bit element. Output is 16 bits to preserve precision for VDOT. Sequential (clocked).

### sparsity.sv
Checks each operand pair for zeros across all 8 slices. Outputs an 8-bit bitmask. Active for VMUL, VMAC, and VDOT only. Defaults to all ones (all active) for other instructions.

### reductiontree.sv
3-level adder tree for VDOT. Takes 8 x 16-bit inputs, produces one 32-bit output. Purely combinational.

### simd.sv
Top level module that wires everything together. Handles instruction decode inline, instantiates all submodules, unpacks operands into per-slice bytes, implements the writeback mux, and assigns outputs.

---

## What Is Left
- Testbench (simd_tb.sv) — in progress
- Python golden model for verification
- SVA assertions
- Performance monitor unit
- Test vector generation and analysis scripts
```