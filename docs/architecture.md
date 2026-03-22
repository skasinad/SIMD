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


This instruction is typically used inside loops to build up dot products or accumulation-based computations across multiple vectors. Sparsity behavior applies to VMAC.
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

By the way, vsrc2 is not used in VLOAD instructions hence it will by default be set to 0.

---

### 7. VSTORE

**VSTORE** writes vector register contents back to memory. This also will not go into any of the ALUs as it is a memory instruction.

The instruction stores the **8 elements of a vector register** into **8 consecutive memory locations**.

This is essentially the inverse operation of VLOAD.
Similarly, vdst is not used in VLOAD instructions hence it will by default be set to 0.

For VSTORE, vsrc1 holds the memory address and vsrc2 will hold the vector data being written to memory. So vsrc2_en which is one of the control signals you will see later as you read on, is going to be asserted for VSTORE even though it is a memory instruction and not an arithmetic one.

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

## Memory System

To support the **VLOAD** and **VSTORE** instructions, this architecture includes a simple on-chip memory block that behaves like a small **SRAM**.

For this project, the SRAM is implemented in a simplified RTL way. In other words, it is not being modeled at the transistor level. Instead, it is just implemented as **an array of registers**. The reason for this is simple: the main goal of this project is to focus on the RTL and microarchitecture side of the SIMD design, not full custom memory cell design. So for this architecture, treating SRAM as a register array is enough to capture the behavior we need.

---

### Total Memory Size

The total memory size is **256 bytes**.

This is enough for the scope of the project while still keeping the design manageable. Since this SIMD unit is a small custom architecture and not a full processor system, the goal here is not to build a huge memory subsystem. The goal is just to have enough memory space to support vector loads and stores cleanly.

---

### SRAM Data Width per Location

Each SRAM location stores **64 bits** of data.

This is pretty self-explanatory if you have been following the architecture so far. Every vector register in the SIMD unit is already **64 bits wide**, and each vector contains **8 INT8 elements**. So if one vector register is 64 bits wide, then it makes the most sense for one memory location to also be **64 bits wide**.

That way:

- one **VLOAD** can bring in one full vector register
- one **VSTORE** can write back one full vector register

So the data width per SRAM location is:

    64 bits = 8 bytes

This keeps the memory system naturally matched to the register file and datapath width.

---

### Number of SRAM Locations

Since the total memory size is **256 bytes**, and each SRAM location stores **8 bytes**, the number of total locations is:

    256 / 8 = 32

So the SRAM contains **32 locations** total.

Again, this follows directly from the design choices already made earlier. Once the vector register width was fixed at 64 bits, it made sense for the memory width to also be 64 bits, and once that is true, the number of locations comes directly from the total memory size.

---

### Address Width

To address **32 locations**, the number of address bits actually needed is:

    log2(32) = 5

So in strict terms, only **5 address bits** are necessary to uniquely select every SRAM location.

However, in this architecture, the SRAM address width is being kept as **8 bits**.

That means:

- **5 bits** are actually used for selecting one of the 32 memory locations
- the remaining **3 bits are reserved**

So effectively, the address format is wider than what is strictly required right now.

The reason for doing this is that it keeps the address format cleaner and more standard-looking, while also leaving some room for future extension if needed. So even though only 5 bits are functionally needed, the design rounds the address width up to 8 bits and treats the extra 3 bits as reserved for now.

---

### Memory Alignment

The memory system uses **8-byte aligned addresses only**.

This also follows pretty naturally from the rest of the architecture. Since each SRAM location is **64 bits wide**, which is **8 bytes**, every valid access should point to one full 64-bit chunk in memory.

So the alignment rule is:

- all valid memory accesses must begin at an address that is a multiple of **8 bytes**

This keeps loads and stores clean, because each memory access maps exactly to one full vector register. In other words, there is no need to split a vector across multiple memory locations or do partial unaligned accesses.

---

### Why This Memory Design Makes Sense

The SRAM design choices all come directly from the earlier microarchitecture decisions.

- The vector register width is **64 bits**
- each vector holds **8 INT8 elements**
- so memory locations are also made **64 bits wide**
- total memory is kept at **256 bytes** for a manageable project scope
- that gives **32 total locations**
- addressing those 32 locations only needs **5 bits**
- but the address is rounded up to **8 bits**, leaving **3 reserved bits**

So overall, the memory system is intentionally designed to match the vector architecture cleanly instead of being made as a separate unrelated block.

---

### Role of SRAM in the SIMD Architecture

The SRAM is mainly used by the **VLOAD** and **VSTORE** instructions.

- **VLOAD** reads one 64-bit memory location and loads that full value into a vector register
- **VSTORE** writes one 64-bit vector register value back into one SRAM location

Because one memory location matches one vector register exactly, these operations stay simple and direct inside the datapath.

## Control Signals

The SIMD architecture also includes a set of **control signals** that work together with the datapath.

In general, a control signal is a signal generated by the control side of the design that tells the datapath **what to do at a given time**. The datapath contains the hardware that actually moves data, performs arithmetic, reads registers, writes results, and handles execution. The control signals are what guide that hardware and make sure the correct operation happens in the correct cycle.

So in a simple way:

- the **datapath** is the part that does the work
- the **control signals** are the part that tell the datapath how to do that work

This relationship is important because the datapath by itself is not enough. Even if the hardware for register reads, ALU operations, reduction, and writeback all exists, the design still needs control logic to decide:

- which registers should be read
- which operation the ALU should execute
- when a writeback should happen
- when a slice should be active or inactive
- when reduction logic should be used
- when memory should be read or written

So the control signals act like the coordination layer between the instruction being decoded and the datapath actually carrying out that instruction.

In this architecture, the control signals come from the decoded instruction and then move through the pipeline along with the data. Their job is to make sure that each stage of the datapath performs the correct action for the instruction currently in execution.

For example, depending on the instruction, the control logic may need to signal that:

- a register file read should happen
- the ALU should perform add, multiply, or ReLU
- sparsity gating should be enabled
- the reduction tree should be used
- the register file write port should be enabled
- the memory block should perform a load or store

### Control Signal Definition

Now that the datapath and instruction behavior are defined, the main control signals for the architecture can also be identified.

In general, these control signals are generated by the control logic after instruction decode, and their job is to guide the datapath so that the correct hardware blocks are active during each instruction.

The control signals chosen for this architecture are listed below.

#### 1. `write_reg_en`

This is the **register file write enable** signal.

Its purpose is to control whether the destination register should be written during the writeback stage. If an instruction produces a result that needs to go back into the register file, this signal is asserted.

Examples of instructions that would use this signal include:

- `VADD`
- `VMUL`
- `VMAC`
- `VRELU`
- `VLOAD`

---

#### 2. `sram_en`

This is the **SRAM enable** signal.

Its job is to activate the SRAM block whenever a memory operation is needed. If the current instruction is not using memory, this signal stays inactive.

This signal is mainly used for:

- `VLOAD`
- `VSTORE`

---

#### 3. `sram_func_en`

This signal controls the **function of the SRAM access**.

Since the SRAM mainly performs two possible operations in this architecture, read or write, this signal tells the memory block which one to perform.

So in simple terms:

- one setting means **SRAM read**
- the other setting means **SRAM write**

This signal is used together with `sram_en`.

---

#### 4. `reduction_en`

This is the **reduction tree enable** signal.

Its purpose is to activate the reduction logic when an instruction needs to combine all slice outputs into one scalar value.

In this architecture, this is specifically needed for:

- `VDOT`

For normal vector instructions, this signal remains inactive because the slice outputs are written back directly as a vector.

---

#### 5. `sparsity_en`

This is the **sparsity check enable** signal.

Its purpose is to activate the sparsity-checking logic during the operand fetch stage. When enabled, the datapath checks whether certain slice operations can be skipped, such as when one operand is zero.

This is mainly useful for instructions where skipping work actually makes sense, such as:

- `VMUL`
- `VMAC`
- `VDOT`

---

#### 6. `writeback_sel`

This is the **writeback source select** signal.

Its job is to determine what data is being written back into the register file.

In this architecture, the writeback source can come from different places depending on the instruction, mainly:

- the **ALU result**
- the **SRAM output data**
- and the **reduction tree output**

For example:

- `VADD` writes back ALU output which will be '01'
- `VLOAD` writes back SRAM data which will be '00'
- `VDOT` writes back reduction tree output which will be '10'

So this signal acts like a mux select for the writeback path.

---

#### 7. `alu_en`

This is the **ALU enable** signal.

Its purpose is to activate slice ALU execution when the instruction requires arithmetic or logical computation.

For instructions that use the SIMD slices to compute results, this signal is enabled. For instructions that are purely memory-driven, this signal may remain inactive.

---

#### 8. `vsrc2_en`

This signal indicates whether the instruction actually needs the **second source operand**.

Not every instruction uses both `vsrc1` and `vsrc2`. For example:

- `VADD` uses `vsrc1` and `vsrc2`
- `VMUL` uses `vsrc1` and `vsrc2`
- `VRELU` only needs `vsrc1`

So this control signal helps avoid unnecessary operand usage when the second source is not required.

Also note that for VSTORE, vsrc is not a arithmetic operand but rather the data register being stored to 
memory. vsrc2_en is still asserted because the register file still needs to read vsrc2 to get the store data.

---

#### 9. `read3_en`

This signal controls whether the **third read port** of the register file is active.

This is important because not every instruction needs three reads. The third read port is mainly needed for instructions such as `VMAC`, where the architecture must read:

- `vsrc1`
- `vsrc2`
- current `vdst`

So this signal is used to activate the third read port only when the instruction requires it.

---

### Control and Datapath Relationship

These control signals are what connect the decoded instruction to the datapath behavior.

The datapath contains the hardware blocks such as:

- the register file
- operand fetch logic
- slice ALUs
- reduction tree
- SRAM
- writeback path

The control signals determine which of those blocks are active, what operation they perform, and how data moves through the pipeline for a given instruction.

So overall, the control logic decides **how the datapath behaves**, while the datapath is the part that actually performs the work.