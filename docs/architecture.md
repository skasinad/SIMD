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

This instruction is also where **sparsity-aware execution** starts to becomes useful.

If either operand element is **zero**, that slice does not need to perform the multiplication. In those cases, the slice can be skipped entirely, which avoids unnecessary compute work.

---

### 3. VMAC

**VMAC** stands for multiply-accumulate.

Each slice multiplies its elements from `vsrc1` and `vsrc2`, then adds the result into an existing accumulator value stored in `vdst`.
vdst[i] = vdst[i] + (vsrc1[i] * vsrc2[i])


This instruction is typically used inside loops to build up dot products or accumulation-based computations across multiple vectors.

Sparsity behavior applies to VMAC.
---

### 4. VDOT

**VDOT** performs a vector dot product.

First, each slice multiplies its elements from `vsrc1` and `vsrc2`.

Then all 8 products are **summed together using a reduction tree** to produce a **single scalar result**.

Unlike the other instructions, which produce a vector output, VDOT produces **one final scalar value**.

Conceptually:
result = sum(vsrc1[i] * vsrc2[i])

Sparsity behavior will also apply to VDOT.

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

**VLOAD** loads data from memory into a vector register. This will not go into any of the ALUs.

The instruction reads **8 consecutive INT8 values** from memory starting at a base address, and places them into the slices of a vector register.

Each slice receives one value.

This allows the entire vector register to be filled in a single instruction.

---

### 7. VSTORE

**VSTORE** writes vector register contents back to memory. This also will not go into any of the ALUs as it is a memory instruction.

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

## Opcode Table

| Instruction | Opcode |
|-------------|--------|
| VADD        | 000    |
| VMUL        | 001    |
| VMAC        | 010    |
| VDOT        | 011    |
| VRELU       | 100    |
| VLOAD       | 101    |
| VSTORE      | 110    |
| RESERVED    | 111    |

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

### Slice ALU and Execution Pipeline

Each of the **8 SIMD slices contains its own ALU**. This follows the basic idea of SIMD execution, where the same instruction is applied across multiple slices of data in parallel. Every slice receives the same decoded instruction, but operates on its own **8-bit element** from the vector operands.

So while the instruction is shared across the whole SIMD unit, the computation itself happens independently inside each slice.

The ALU is responsible for executing the vector arithmetic and logical operations defined in the instruction set. The operation performed by the ALU is determined by the **opcode** field of the instruction.

Because all slices execute the same instruction at the same time, the SIMD datapath behaves like **8 identical processing slices running in parallel**.

---

### Pipeline Structure

The ALU execution follows a **4-stage pipeline**. This pipeline structure is commonly used in SIMD architectures because it cleanly separates instruction handling, operand movement, computation, and result writeback.

In this design, every instruction follows the same **fixed latency of 4 cycles**. Using a uniform latency simplifies control logic and keeps the execution model predictable.

The four stages are:

1. **Fetch & Decode**
2. **Operand Fetch + Sparsity Check**
3. **Execute**
4. **Reduction / Writeback**

Each stage performs a specific part of the instruction execution process.

---

### Stage 1 — Fetch & Decode

In the first stage, the instruction is fetched and decoded.

The hardware reads the **16-bit instruction** and extracts the instruction fields:

- `opcode`
- `vdst`
- `vsrc1`
- `vsrc2`

The opcode determines which vector operation will be executed by the ALU in the later stages. The register indices are used to select the appropriate registers from the vector register file.

After decoding, the instruction information is forwarded to the next stage of the pipeline.

---

### Stage 2 — Operand Fetch + Sparsity Check

In the second stage, the SIMD unit reads the required operands from the **vector register file**.

Using the register indices decoded in the previous stage, the hardware performs the required register reads. Because the register file has **three read ports**, it can fetch:

- `vsrc1`
- `vsrc2`
- the current value of `vdst` (when required, such as for VMAC)

Each register read returns a **64-bit vector value**.

The datapath then unpacks these values into **8 individual INT8 elements**, which are routed to the corresponding SIMD slices.

At this point, the architecture also performs a **sparsity check**.

For operations such as multiplication, if one of the operands is **zero**, the computation for that slice can be skipped because the result will not contribute useful work.

To support this optimization, the hardware checks each slice's operands and generates a **slice activity mask**:
slice_active[7:0]

Each bit of this mask indicates whether a slice should execute the operation or remain inactive.

Inactive slices are gated before entering the execution stage so that they do not perform unnecessary work.

---

### Stage 3 — Execute

In the third stage, the actual computation takes place inside the ALUs.

Each slice receives:

- its **8-bit operands**
- the **opcode**
- the **slice_active** control bit

If the slice is active, the ALU executes the operation specified by the opcode using a simple **case statement** structure. This selects the correct arithmetic or logical operation such as:

- addition
- multiplication
- multiply-accumulate
- ReLU activation

If the slice is inactive according to the slice mask, the ALU simply performs no operation during that cycle.

Because all slices run in parallel, the SIMD unit computes results for up to **8 elements simultaneously** during this stage.

---

### Stage 4 — Reduction and Writeback

The final stage handles result completion and writing results back to the register file.

For most vector instructions such as **VADD, VMUL, VMAC, and VRELU**, the output of each slice is written directly back into the destination vector register.

Since each slice produces one element, the **8 slice outputs are packed back together into a 64-bit vector value**, which is then written through the register file's single write port into `vdst`.

The **VDOT instruction** is slightly different.

Instead of producing a vector result, VDOT produces a **single scalar value**. After each slice computes its multiplication result, those values are passed through a **reduction tree** that sums all slice outputs together.

The reduction tree combines the partial products to generate the final dot-product result before it is written back.

### Reduction Tree

To support the **VDOT instruction**, the datapath includes a structure called a **reduction tree**.

The purpose of the reduction tree is to take the **8 multiplication results coming from the slices** and combine them into a **single scalar value**. This is necessary because VDOT produces one final scalar output instead of a vector.

Instead of adding the slice results sequentially, the design uses a **parallel reduction tree**. This allows the datapath to sum multiple values at the same time, which is much more efficient.

The reduction tree works by combining partial sums across multiple levels.

Since there are **8 slice outputs**, the number of reduction levels required is determined by log2(8) = 3.


So the reduction tree has **3 levels**:

- **Level 1:** 8 inputs are reduced to 4 partial sums  
- **Level 2:** 4 partial sums are reduced to 2 partial sums  
- **Level 3:** 2 partial sums are reduced to the final result  

This structure allows all slice results to be combined in a small number of stages instead of performing additions one after another.

### Result Width

The reduction tree produces a **32-bit output value**.

This wider result is necessary because the intermediate values produced during the dot product can become much larger than what an INT8 value can hold.

For example:

- The maximum value of an INT8 number is **127**
- The largest multiplication inside a slice would be 127 * 127 = 16129.


This value already cannot fit inside an INT8.

Now consider the full dot product across all 8 slices which would be 127 added 8 times to itself so 127 + 127 + 127 + 127 + 127 + 127 + 127 + 127...
that is coming to 129032.

A value of **129032** also cannot be represented using INT8.

Because of this, the architecture uses a **32-bit accumulator for the reduction result**, which safely holds the final scalar output produced by the dot product operation.