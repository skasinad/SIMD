/*
each slice needs to get one part of the 8-bit value coming from the register

8 bits from vsrc1
8 bits from vsrc2
8 bits from accumulator value
3 bits of opcode
also 1 enable bit
total 28 bits
*/


module slice#(
    parameter int BYTE = 8
) (
    input logic clk, 
    input logic rst,
    input logic enable,

    input logic[BYTE-1:0] num1, 
    input logic[BYTE-1:0] num2,
    input logic[BYTE-1:0] acum, 
    input logic[2:0] opcode,
    //value can be up to 16 bits because of the multplication instructions
    output logic[15:0] value  
);
    //only going to keep the opcodes up till VREUL b/c these are the only "mathematics" instructions
    parameter logic[2:0] VADD = 3'b0;
    parameter logic[2:0] VMUL = 3'b001;
    parameter logic[2:0] VMAC = 3'b010; 
    parameter logic[2:0] VDOT = 3'b011;
    parameter logic[2:0] VRELU = 3'b100;

    always_ff @(posedge clk) begin 
        if(rst)
            value <= 0;
        else begin 
            if(enable) begin 
                case(opcode)
                    VADD: value <= num1 + num2; 
                    VMUL: value <= num1 * num2; 
                    VMAC: value <= acum + (num1 * num2);
                    VDOT: value <= num1 * num2; //just the same as VMUL b/c the adding happens in reduction
                    VRELU: 
                        if ($signed(num1) < 0) //completely forgot its unisgned by default had to use $signed() and then it started working
                            value <= 0; 
                        else 
                            value <= num1; 
                    default: value <= 0;
                endcase 
            end 
          
        end
    end  

endmodule