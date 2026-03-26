# SIMD Vector Processing Unit v1.0

A custom pipelined SIMD (Single Instruction Multiple Data) vector processing unit built from scratch in SystemVerilog.

This is a portfolio project I made to show my microarchitecture design and hardware verification skills. But more than that, I also wanted this project to show how I was thinking while designing the system, not just the final output.

This is **not** a general purpose CPU. Its a specialized vector compute engine, similar in concept to ARM NEON or RISC-V vector extensions. The design processes 8 elements in parallel using INT8 (signed 8-bit integers), which is a data type commonly used in ML inference style hardware.

This is the **first version** of the project. I still want to expand the ISA more, improve verification, and build more around it. See the [Next Steps](#next-steps) section for where I want to take it later.

---

## Author's Note

I wanted to add a more personal note here because this project was not just about making something that works.

A big reason I made this was to show how I think when I design hardware systems. That is also why I left a lot of comments in the modules and documentation. I wanted the thought process to be visible, not just the final code. A lot of times on projects people only see the polished version at the end, but for this one I felt like the actual design thinking mattered too.

So if you are reading through this repo, you are not just looking at the final system. You are also seeing how I was reasoning through the control flow, datapath decisions, instruction behavior, and overall structure while building it.

I also hope people can use this to give me feedback. If you see something I could improve, structure better, verify better, or even rethink completely, that would genuinely help me. And if someone is learning from this too, then that is a bonus I would be really happy about.

---

## Architecture Overview

- **Data type:** INT8 (signed 8-bit)
- **Vector width:** 64 bits per register, 8 elements processed in parallel
- **Register file:** 16 vector registers, 3 read ports, 1 write port
- **Memory:** 256 byte SRAM, 32 locations, 64 bits each
- **Pipeline:** 4 stages — Decode, Operand Fetch + Sparsity, Execute, Reduction + Writeback
- **Sparsity-aware execution** for multiply operations — skips slices with zero operands
- **Reduction tree** for VDOT — 3-level parallel adder tree

For the full architecture breakdown including control signals, ISA encoding, writeback paths, and design decisions, see [docs/architecture.md](docs/architecture.md).

---

## Instruction Set

7 instructions, 16-bit fixed-width encoding:

| Opcode | Instruction | Description |
|--------|-------------|-------------|
| 000 | VADD | Element-wise addition |
| 001 | VMUL | Element-wise multiplication (sparsity-aware) |
| 010 | VMAC | Multiply-accumulate (sparsity-aware) |
| 011 | VDOT | Dot product with reduction tree (sparsity-aware) |
| 100 | VRELU | ReLU activation, clamps negative values to zero |
| 101 | VLOAD | Load 8 INT8 values from SRAM into a vector register |
| 110 | VSTORE | Write a vector register into SRAM |
| 111 | RESERVED | Reserved |

Encoding format:

    [opcode(3) | vdst(4) | vsrc1(4) | vsrc2(4) | MBZ(1)]

---

## File Structure

    SIMD/
    ├── rtl/
    │   ├── simd.sv            ← top level module, wires everything together
    │   ├── control.sv         ← combinational control signal generator
    │   ├── registers.sv       ← 16-entry vector register file
    │   ├── slice.sv           ← single compute slice (8 instantiated in top)
    │   ├── reductiontree.sv   ← 3-level parallel adder tree for VDOT
    │   ├── sparsity.sv        ← zero operand detection, generates skip mask
    │   └── sram.sv            ← 32-location, 64-bit wide memory
    ├── tb/
    │   └── simd_tb.sv         ← testbench for all 7 instructions
    ├── assertions/
    │   └── asserts.sv         ← concurrent SVA properties
    ├── python/
    │   └── baseline.py        ← golden model reference for verification
    ├── docs/
    │   ├── architecture.md    ← full architecture documentation
    │   └── diagrams/
    │       └── simd_top_level_block_diagram
    └── README.md

---

## Verification

### Testbench

All 7 instructions were tested and are passing in simulation using Icarus Verilog. The testbench preloads SRAM with known data, runs each instruction, and displays the results.

    VADD  result: 110f0d0b09070503    ✓
    VMUL  result: 48382a1e140c0602    ✓
    VMAC  result: 48382a1e140c0602    ✓
    VDOT  scalar: 240                 ✓
    VRELU result: 0800060004000200    ✓
    Sparsity test: 4000240010000400   ✓
    VSTORE mem[4]: 110f0d0b09070503   ✓

### Assertions

There are concurrent SVA properties in `assertions/asserts.sv` covering:

- Reset clears valid
- Scalar output stays zero unless VDOT is being executed
- VDOT always uses the reduction path
- VLOAD always uses the SRAM path
- SRAM write is only enabled during VSTORE
- Sparsity is only active for multiply-based operations

Syntax was checked with Verilator using `--lint-only` and passed with zero errors. Runtime checking for the assertions is intended to be done on EDA Playground.

### Python Golden Model

There is also a baseline Python reference model in `python/baseline.py` that independently computes expected outputs for VADD, VMUL, VMAC, VDOT, and VRELU. The outputs from the Python model match the RTL simulation results for the current test cases.

Right now this golden model is still pretty small. It covers the core operations with basic test vectors. Later on I want to expand it with randomized inputs, more edge cases, and automated comparison against RTL output.

### Waveform Analysis

For waveform debugging and checking internal signal behavior, I used **ModelSim**. This helped with looking at how signals changed across time, checking writeback behavior, and making sure the datapath and control flow were behaving the way I intended during simulation.

---

## How to Run

### Compile and Simulate

    iverilog -g2012 -o simd_sim rtl/*.sv tb/simd_tb.sv
    vvp simd_sim

### Run Assertion Syntax Check

    verilator --lint-only -Wall assertions/asserts.sv

### Open in ModelSim

Compile the RTL and testbench in ModelSim, run the simulation, and inspect the internal signals in the waveform viewer. This is what I used for waveform-level debugging.

---

## Design Highlights

### 1. SIMD Execution

The core datapath operates on 8 packed INT8 lanes at once. Instead of processing one scalar at a time, the design performs vector operations across all 8 slices in parallel.

### 2. Sparsity Support

For multiply-based instructions like `VMUL`, `VMAC`, and `VDOT`, the design includes sparsity-aware logic. If either operand in a slice is zero, that slice can be skipped. This is useful because a lot of ML-style workloads have many zero-valued elements.

### 3. Dedicated Reduction Path for VDOT

`VDOT` does not write back a full vector. Instead, it sends the 8 slice products into a 3-level reduction tree and produces a scalar output. This gives `VDOT` a distinct execution/writeback path compared to the normal vector ALU operations.

### 4. Separate SRAM Data Path

`VLOAD` and `VSTORE` directly interact with the SRAM path. That means the memory path is not just an afterthought here, it is built into the architecture and instruction behavior from the start.

---

## Why I Built This

I wanted to make something that felt closer to real digital design than just another basic Verilog class project.

This project gave me a way to think through:

- instruction behavior
- control signal generation
- datapath organization
- pipeline structure
- vector execution
- memory integration
- verification planning

It also let me document design choices more clearly, which is something I wanted to get better at, because in actual hardware work the explanation behind the system matters a lot too.

---

## Current Limitations

This is still version 1, so there are definitely things I would improve.

- Testbench is still directed, not fully automated
- Assertions are written, but full runtime assertion checking depends on simulator support
- No hazard handling or forwarding logic
- No instruction memory or fetch stage
- ISA is still small and intentionally simple
- No parameterization yet for vector length or memory depth
- Verification coverage is still limited compared to a full industry flow

---

## Next Steps

Some things I want to improve in later versions:

- add more vector instructions
- improve the testbench and make it more self-checking
- add randomized verification
- expand the Python golden model
- improve documentation and module-level diagrams
- explore parameterizing vector width and register count
- maybe add a cleaner instruction issue/fetch structure later on

---

## Final Thoughts

This project was mainly about building a working SIMD-style vector engine while also documenting the design process behind it.

I wanted the repo to show both the system itself and the way I was thinking through the design. So even if some parts are still version-1 level, that was part of the point too. I would rather show the real process with clear comments and structure than try to make it look artificially polished.

And again, if you are reading this and have feedback, that is something I would genuinely appreciate.