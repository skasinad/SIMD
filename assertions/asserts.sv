/*
I am going to use SystemVerilog Concurrent Assertions
My system uses icarus which arent compatible for concurrent SVAs
so I will run them on the EDA playground tool

Couple of rules i want to implement: 
- Reset needs to always clear the valid when its high 
- Scalar output will always be 0 unless VDOT is run
- VDOT will always use reduction going to have to use overlapping SVAs tho bc of this
- VLOAD will always use SRAM
- SRAM write enabled only during VSTORE
- Sparsity will be active only for the ones with multiplication
*/


module asserts (
    input logic clk, 
    input logic rst, 
    input logic[2:0] opcode, 
    input logic valid,
    input logic[31:0] scalar,
    input logic [1:0] writeback_sel,
    input logic sram_func_en, 
    input logic sparsity_en
); 

    //all the local opcodes
    localparam logic[2:0] VADD = 3'b0;
    localparam logic[2:0] VMUL = 3'b001;
    localparam logic[2:0] VMAC = 3'b010;
    localparam logic[2:0] VDOT = 3'b011;
    localparam logic[2:0] VRELU = 3'b100;
    localparam logic[2:0] VLOAD = 3'b101;
    localparam logic[2:0] VSTORE = 3'b110;

    assert property(@(posedge clk) rst |-> !valid) else $error("assertion failed bc valid is high during reset");

    assert property(@(posedge clk) disable iff (rst) opcode != VDOT |-> scalar == 32'b0) else $error("assertion failed... scalar output despite non VDOT instruction");

    assert property(@(posedge clk) disable iff (rst) opcode == VDOT |-> writeback_sel == 2'b10) else $error("assertion failed, VDOT not using the reduction path");
    assert property(@(posedge clk) disable iff (rst) opcode == VLOAD |-> writeback_sel == 2'b00) else $error("failed VLOAD not using SRAM path");

    assert property(@(posedge clk) disable iff (rst) sram_func_en |-> opcode == VSTORE) else $error("assertion failed SRAM has become enabled during instruction not VSTORE");


    assert property(@(posedge clk) disable iff (rst) sparsity_en |->(opcode == VMUL || opcode== VMAC || opcode == VDOT)) else $error("assertion has failed, sparsity enabled for wrong instrcutions");

    //more assertions to come... this is just the first 6 i could think of

endmodule 