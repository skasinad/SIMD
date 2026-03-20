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