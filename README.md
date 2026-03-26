# SIMD Vector Processing Unit v1.0

A custom pipelined SIMD (Single Instruction Multiple Data) vector processing unit built from scratch in SystemVerilog. This is a portfolio project designed to show microarchitecture design and hardware verification skills.

This is **not** a general purpose CPU — its a specialized vector compute engine, similar in concept to ARM NEON or RISC-V vector extensions. The design processes 8 elements in parallel using INT8 (signed 8-bit integers), a data type widely used in ML inference hardware.

This is explicitly the **first version** of this project. There are plans to expand the ISA, add more verification, and build out the tooling around it. See the [Next Steps](#next-steps) section for whats coming.

---

## Architecture Overview

- **Data type:** INT8 (signed 8-bit)
- **Vector width:** 64 bits per register, 8 elements processed in parallel
- **Register file:** 16 vector registers, 3 read ports, 1 write port
- **Memory:** 256 byte SRAM, 32 locations, 64 bits each
- **Pipeline:** 4 stages — Decode, Operand Fetch + Sparsity, Execute, Reduction + Writeback
- **Sparsity aware execution** for multiply operations — skips slices with zero operands
- **Reduction tree** for VDOT — 3-level parallel adder tree

For the full architecture breakdown including control signals, ISA encoding, writeback paths, and design decisions, see [docs/architecture.md](docs/architecture.md).

---

## Instruction Set

7 instructions, 16-bit fixed width encoding:

| Opcode | Instruction | Description |
|--------|------------|-------------|
| 000 | VADD | Element-wise addition |
| 001 | VMUL | Element-wise multiplication (sparsity aware) |
| 010 | VMAC | Multiply-accumulate (sparsity aware) |
| 011 | VDOT | Dot product with reduction tree (sparsity aware) |
| 100 | VRELU | ReLU activation, clamps negatives to zero |
| 101 | VLOAD | Load 8 INT8 values from SRAM into a vector register |
| 110 | VSTORE | Write a vector register to SRAM |
| 111 | RESERVED | — |

Encoding format: `[opcode(3) | vdst(4) | vsrc1(4) | vsrc2(4) | MBZ(1)]`

---

## File Structure

```
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
│   └── simd_tb.sv         ← testbench, verifies all 7 instructions
├── assertions/
│   └── asserts.sv         ← 6 concurrent SVA properties
├── python/
│   └── baseline.py        ← golden model reference for verification
├── docs/
│   ├── architecture.md    ← full architecture documentation
│   └── diagrams/
│       └── simd_top_level_block_diagram
└── README.md
```

---

## Verification

### Testbench
All 7 instructions tested and passing in simulation using Icarus Verilog. Testbench preloads SRAM with known data, runs each instruction, and displays results.

```
VADD  result: 110f0d0b09070503    ✓
VMUL  result: 48382a1e140c0602    ✓
VMAC  result: 48382a1e140c0602    ✓
VDOT  scalar: 240                 ✓
VRELU result: 0800060004000200    ✓
Sparsity test: 4000240010000400   ✓
VSTORE mem[4]: 110f0d0b09070503   ✓
```

### Assertions
6 concurrent SVA properties in `assertions/asserts.sv` covering:
- Reset clears valid
- Scalar output is zero unless VDOT
- VDOT always uses reduction path
- VLOAD always uses SRAM path
- SRAM write only enabled during VSTORE
- Sparsity only active for multiply operations

Syntax verified with Verilator `--lint-only` (zero errors). Runtime validation to be completed on EDA Playground.

### Python Golden Model
A baseline Python reference model in `python/baseline.py` that independently computes expected results for VADD, VMUL, VMAC, VDOT, and VRELU. All outputs match the RTL simulation results.

This golden model is still very small right now — it covers the core operations with basic test vectors. Future iterations will expand it with randomized inputs, edge case coverage, and automated comparison against RTL output.

---

## How to Run

### Compile and Simulate

```bash
iverilog -g2012 -o simd_sim rtl/control.sv rtl/registers.sv rtl/sram.sv rtl/slice.sv rtl/sparsity.sv rtl/reductiontree.sv rtl/simd.sv tb/simd_tb.sv
vvp simd_sim
```

### Run Golden Model

```bash
python3 python/baseline.py
```

### Lint Assertions

```bash
verilator --lint-only -Wall assertions/asserts.sv
```

---

## Next Steps

This is v1.0. Heres whats planned for future iterations:

- **Expand the ISA** — add instructions like VSUB (subtraction), VMAX/VMIN (element-wise max/min), VSHIFT (bit shifting), and VABS (absolute value)
- **More SVA assertions** — add coverage for writeback path correctness, register write disable during VSTORE, sparsity mask validation against operand data
- **Performance Monitor Unit (PMU)** — track cycle counts, instruction counts, sparsity skip rates, and ALU utilization
- **Expand the golden model** — randomized test vectors, automated RTL vs Python comparison, overflow and edge case testing
- **Hazard detection** — add data hazard detection and forwarding for back-to-back dependent instructions
- **Pipeline registers** — add explicit pipeline stage registers with proper valid/stall handshaking
- **Test vector generator** — Python script to generate random instruction sequences and expected results
- **Waveform analysis** — GTKWave integration for visual pipeline debugging

---

## Tools Used

- **SystemVerilog** — RTL design and testbench
- **Icarus Verilog** — simulation
- **Verilator** — assertion linting
- **Python 3** — golden model
- **GTKWave** — waveform viewing (optional)

---

## License

This is a personal portfolio project. Feel free to look around and learn from it.
```