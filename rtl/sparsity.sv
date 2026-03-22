/*
This is my sparcity detection implementation.

Need to check each of the operands from the slices if there are total 8 slices so then
16 operands need to be checked totally

8 of num1 8 of num2...

maybe can define some sort of buffer 1s are all execute and then 0s for ignoring??

inputs need to be the operands from the slice.. ahh maybe defining two operands as inputs each 8 bits long
output will be the buffer?

nvm need it for all 8
opcode input b/c we dont need this for all the intructions

sparsity only applies to VMUL VMAC and VDOT
*/


module sparsity (
    input logic clk, 
    input logic rst,
    input logic[2:0] opcode, 
    input logic[7:0] oper1[7:0],
    input logic[7:0] oper2[7:0], 
    output logic[7:0] buffer //realized after testing this only needs to be 8 b/c its just one slice
);

    always_ff @(posedge clk) begin 
        if(rst) begin
            buffer <= 8'b11111111; 
        end else begin
            if(opcode == 3'b001 || opcode == 3'b010 || opcode == 3'b011) begin
                for(int i = 0; i < 8; i++) begin
                    if(oper1[i] == 8'b0 || oper2[i] == 8'b0) begin
                        buffer[i] <= 0; //that specific bit bcomes 0
                    end else begin
                        buffer[i] <= 1; 
                    end   
                end  
                //need to also consider the other instructions
            end else begin
                buffer <= 8'b11111111;  

            end
        end
    end   
endmodule