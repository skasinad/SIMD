# SIMD

## Overview

This project implements a custom **SIMD (Single Instruction Multiple Data) accelerator** written in **SystemVerilog**. The goal of the project was to design and verify a small vector processing engine that can perform parallel operations on quantized data, similar to the kinds of operations used in modern AI and signal processing workloads.

Instead of just making a basic ALU or vector unit, the idea here was to build something that feels more like a **small domain-specific accelerator**. The design focuses on low precision integer computation (mainly INT8) and includes logic that can detect sparsity in input data and avoid doing unnecessary work in certain SIMD lanes.

The project was simulated and verified using **ModelSim**, with additional correctness checking done through a **Python + NumPy golden model**.

Overall the goal of the project was to explore:

- SIMD microarchitecture design  
- vector register files and datapaths  
- quantized AI-style arithmetic operations  
- sparsity-aware execution  
- hardware performance monitoring  
- verification using SystemVerilog assertions and Python reference models  

---

## Motivation

Modern AI workloads rely heavily on vector operations like dot products, multiply-accumulate loops, and activation functions. Many hardware accelerators optimize these workloads using parallel datapaths and low precision arithmetic.

This project explores a simplified version of that idea by implementing a custom SIMD datapath that operates on quantized vectors and supports common vector math operations. The design also experiments with **sparsity-aware execution**, where compute lanes can skip unnecessary work when input operands contain zeros.

The goal was not to build a full AI accelerator, but to better understand how small specialized compute blocks are designed and verified at the RTL level.

---

## Features

- Parameterized SIMD architecture  
- Parallel vector computation across multiple lanes  
- INT8 quantized arithmetic support  
- Vector register file for operand storage  
- Dot-product style reduction operations  
- ReLU-style activation support  
- Sparsity-aware lane skipping logic  
- Built-in performance monitoring counters  
- ModelSim simulation and waveform analysis  
- Python + NumPy golden model for verification  

---

## Supported Operations

The SIMD unit supports several vector operations commonly used in signal processing and AI workloads.

Examples include:

- **VADD** – element-wise vector addition  
- **VMUL** – element-wise vector multiplication  
- **VMAC** – vector multiply-accumulate  
- **VDOT** – vector dot product with reduction  
- **VRELU** – ReLU activation (clamps negative values to zero)

These operations operate across all SIMD lanes in parallel.

---

## Sparsity-Aware Execution

One of the experimental ideas in this design is **sparsity-aware execution**.

During certain operations such as multiplication or multiply-accumulate, the hardware checks if one of the operands is zero. If it is, that SIMD lane can skip the computation instead of performing unnecessary work.

This allows the design to:

- reduce wasted operations  
- track skipped computations  
- analyze lane utilization  

Performance monitoring counters record how many lanes were active vs skipped during execution.

---

## Performance Monitoring

The accelerator also includes a small **PMU (Performance Monitoring Unit)** that tracks runtime behavior of the SIMD engine.

Some of the monitored metrics include:

- total cycles executed  
- number of instructions executed  
- active SIMD lane count  
- skipped sparse lane count  

These counters help analyze how efficiently the SIMD hardware is being utilized under different workloads.

---

## Tech Stack

The following tools and technologies were used for the project:

- **SystemVerilog** – RTL design  
- **SystemVerilog Assertions** – verification checks  
- **ModelSim** – simulation and waveform debugging  
- **Python** – reference modeling and analysis  
- **NumPy** – vector math golden model  
- **Git + GitHub** – version control and documentation  

---

## Repository Structure

```text
SIMD/
├── rtl/
│   ├── simd_top.sv
│   ├── simd_decoder.sv
│   ├── vector_regfile.sv
│   ├── simd_lane.sv
│   ├── reduction_unit.sv
│   ├── sparsity_ctrl.sv
│   └── simd_pmu.sv
├── tb/
│   └── simd_tb.sv
├── assertions/
│   └── simd_properties.sv
├── python/
│   ├── golden_model.py
│   ├── vector_generator.py
│   └── analysis.py
├── docs/
│   ├── architecture.md
│   └── diagrams/
└── README.md


---

