/*
each slice needs to get one part of the 8-bit value coming from the register

8 bits from vsrc1
8 bits from vsrc2
8 bits from accumulator value
3 bits of opcode
also 1 enable bit

*/


module slice#(
    parameter int BYTE = 8
) (
    input logic clk, 
    input logic rst,
    input logic enable,

    input logic[BYTE-1:0] elem1, 
    input logic[BYTE-1:0] elem2,
    input logic[BYTE-1:0] acum, 
    input logic[2:0] opcode,
    //value can be up to 16 bits because of the multplication instructions
    output logic[15:0] value  
);


endmodule;