# SIMD Microarchitecture

## Overview

This document explains the microarchitecture of the SIMD unit implemented in this project. The goal of this design is to build a small but realistic vector compute engine that can perform common vector math operations used in machine learning and signal processing workloads.

The architecture focuses on low precision arithmetic and parallel execution across multiple slices (lanes). It is designed to be simple enough to implement and verify in RTL, while still capturing the key ideas behind real SIMD compute hardware.

---

## Data Type

The SIMD unit operates on **INT8 data**.

INT8 simply means a signed integer that is **8 bits wide**. Each element stored in the vector registers is an 8-bit integer.

This data type was chosen for two main reasons:

- **INT8 is widely used in modern machine learning inference hardware**, especially for quantized neural networks.
- **INT8 arithmetic is very efficient in hardware**, since the datapath width is small and the silicon cost is relatively low.

Because of this, INT8 makes a good balance between practical relevance and manageable RTL complexity.

---

## Vector Width and Slices

Each vector register in the architecture is **64 bits wide**.

Since each element is **8 bits**, a single register holds:
64 bits/8 bits per element = 8 elements

So, this means the SIMD unit processes **8 elements in parallel**, which will be called as **slices**. Each slice is responsible for operating on one element of the vector.

So the SIMD unit contains:

- **8 slices**
- each slice processes **one INT8 element**
- all slices operate **in parallel**

This allows the architecture to perform vector operations across all elements simultaneously.

---

## Vector Register File

The design contains **16 vector registers**.

Each register is:

- **64 bits wide**
- holds **8 INT8 elements**

To identify registers inside instructions, **4 bits** are used for the register index.

This allows addressing 2^4 which is 16 registers. The register file stores operands and results for all vector operations.

---

## Instruction Set

The microarchitecture supports **7 vector instructions**. These instructions cover the most important operations needed for vector math and simple machine learning workloads.

### 1. VADD

**VADD** performs element-wise addition.

Each slice adds its element from `vsrc1` to the corresponding element in `vsrc2`, and the result is written to `vdst`.

All **8 slices perform the addition in parallel**. For example: 
vdst[i] = vsrc1[i] + vsrc2[i]... for all slices that i = 0 through 7.

---

### 2. VMUL

**VMUL** performs element-wise multiplication.

The structure is similar to VADD, except that multiplication is performed instead of addition.
vdst[i] = vsrc1[i] * vsrc2[i].

This instruction is also where **sparsity-aware execution** becomes useful.

If either operand element is **zero**, that slice does not need to perform the multiplication. In those cases, the slice can be skipped entirely, which avoids unnecessary compute work.

---

### 3. VMAC

**VMAC** stands for multiply-accumulate.

Each slice multiplies its elements from `vsrc1` and `vsrc2`, then adds the result into an existing accumulator value stored in `vdst`.
vdst[i] = vdst[i] + (vsrc1[i] * vsrc2[i])


This instruction is typically used inside loops to build up dot products or accumulation-based computations across multiple vectors.

---

### 4. VDOT

**VDOT** performs a vector dot product.

First, each slice multiplies its elements from `vsrc1` and `vsrc2`.

Then all 8 products are **summed together using a reduction tree** to produce a **single scalar result**.

Unlike the other instructions, which produce a vector output, VDOT produces **one final scalar value**.

Conceptually:
result = sum(vsrc1[i] * vsrc2[i])

---

### 5. VRELU

**VRELU** implements the ReLU (Rectified Linear Unit) activation function commonly used in neural networks.

Each slice independently checks its input value:

- if the value is **negative**, the output becomes **0**
- otherwise the value passes through unchanged
vdst[i] = max(0, vsrc1[i])

This instruction only requires `vsrc1`.

---

### 6. VLOAD

**VLOAD** loads data from memory into a vector register.

The instruction reads **8 consecutive INT8 values** from memory starting at a base address, and places them into the slices of a vector register.

Each slice receives one value.

This allows the entire vector register to be filled in a single instruction.

---

### 7. VSTORE

**VSTORE** writes vector register contents back to memory.

The instruction stores the **8 elements of a vector register** into **8 consecutive memory locations**.

This is essentially the inverse operation of VLOAD.

---

## Instruction Format

The architecture uses a **16-bit instruction format**.

Since the design has **7 instructions**, the opcode must encode at least 7 values.

Using **3 bits** allows up to 2^3 which is 8 instructions.

So the opcode field is **3 bits wide**.

The register fields are **4 bits each**, since there are 16 registers.

The instruction format is therefore:
[opcode(3 bits) | vdst(4 bits) | vsrc1(4 bits) | vsrc2(4 bits) | reserved(1 bit)]

The final 1 bit is reserved due to the sake of rounding from 15 bits to 16 bits.


## Register File

The SIMD register file is designed with **4 total ports**:

- **3 read ports**
- **1 write port**

The reason for this comes directly from looking at the instruction behavior and identifying the **worst-case register access pattern**.

The most demanding instruction in this architecture is **VMAC**.

For VMAC, in a single cycle, the hardware needs to:

1. read `vsrc1`
2. read `vsrc2`
3. read the current value already stored in `vdst`
4. write the updated result back into `vdst`

So in total, VMAC needs:

- **3 reads**
- **1 write**

Because of that, the register file must support at least **3 simultaneous read accesses** and **1 write access** in order to execute the instruction cleanly in a single cycle.

Even though not every instruction needs all 3 read ports, the register file is designed around the **worst-case instruction requirement**, since that determines the minimum number of ports needed for correct operation.

### Read Ports

The register file uses **3 synchronous read ports**.

These read ports are used for:

- `vsrc1`
- `vsrc2`
- current `vdst` value when needed, such as in VMAC

Using 3 read ports allows the architecture to fetch all required source operands in the same cycle for the most demanding operations.

### Write Port

The register file has **1 write port**.

This write port is used to write the final result back into the destination register.

Since every instruction produces at most one destination register update at a time, **1 write port is sufficient** for this microarchitecture.

## Datapath

The datapath begins with the **operand fetch path**.

As already defined in this architecture, each register in the register file is **64 bits wide**. That means when a source register is read, the register file outputs **one full 64-bit vector value**.

However, the SIMD slices do not operate on the full 64-bit value as one single piece. Each slice only works on **one INT8 element**, which means the operand fetch path has to prepare that register output before it can be used by the slices.

### Operand Fetch Path

The job of the operand fetch path is to take the **64-bit value coming out of the register file** and split it into **8 separate 8-bit elements**.

So instead of treating the register output as one large block, the datapath breaks it into:

- element 0 → 8 bits  
- element 1 → 8 bits  
- element 2 → 8 bits  
- element 3 → 8 bits  
- element 4 → 8 bits  
- element 5 → 8 bits  
- element 6 → 8 bits  
- element 7 → 8 bits  

This step is necessary because the SIMD architecture is built around **8 slices**, and each slice is responsible for processing exactly **one 8-bit element**.

### Slice Assignment

After the 64-bit operand is broken into 8 separate 8-bit values, the operand fetch path then routes those values to the slices.

Each slice receives its own corresponding element.

So the mapping is straightforward:

- **slice 0** gets element 0  
- **slice 1** gets element 1  
- **slice 2** gets element 2  
- **slice 3** gets element 3  
- **slice 4** gets element 4  
- **slice 5** gets element 5  
- **slice 6** gets element 6  
- **slice 7** gets element 7  

This way, all 8 slices receive their input data in parallel.

### Why This Matters

This part of the datapath is what allows the SIMD unit to actually behave like a vector engine.

The register file stores the vector as **one 64-bit register**, but the compute hardware works on that vector as **8 parallel INT8 elements**.

So the operand fetch path acts as the bridge between:

- the **register-level view** of the data  
and  
- the **slice-level view** of the data

Without this step, the slices would not be able to operate independently on the elements of the vector.