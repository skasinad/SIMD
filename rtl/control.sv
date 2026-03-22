/*
Where all my control signals are going to be
total there are 9 signals, each signal and its purpose is in the architecture document so plz read it

I think best way is just writing the opcodes for each instruction and in a case just set the signals to 1

Problem is VDOT is scalar not vector so scalar still needs to go somewhere after reduction tree finishes
it is producing a third reuslt so having only two options in writeback_sel for 0 and 1 wont really work

I think maybe I can just change writeback_sel signal from 1 bit to 2 bit?
Then I can add 3 signals per opcode only for writbeack_sel...

can say like 00 is for SRAM 01 is for ALU and then 10 will be for the reduction tree
this should have already been updated in architecture.md, so if you are reading all this your just seeing my thought process
behind the change.

*/


module control (
    input logic[2:0] opcode, 
    
    //control signals
    output logic write_reg_en, 
    output logic sram_en, 
    output logic sram_func_en, 
    output logic reduction_en, 
    output logic sparsity_en, 
    output logic[1:0] writeback_sel, 
    output logic alu_en,
    output logic vsrc2_en, 
    output logic read3_en
);
    //all the instructions
    parameter logic[2:0] VADD = 3'b0;
    parameter logic[2:0] VMUL = 3'b001;
    parameter logic[2:0] VMAC = 3'b010; 
    parameter logic[2:0] VDOT = 3'b011;
    parameter logic[2:0] VRELU = 3'b100;
    parameter logic[2:0] VLOAD = 3'b101;
    parameter logic[2:0] VSTORE = 3'b110;

    always_comb begin 
        case(opcode)
            VADD: begin 
                write_reg_en = 1;
                sram_en = 0; 
                sram_func_en = 0;
                reduction_en = 0;
                sparsity_en = 0;
                writeback_sel = 2'b01; 
                alu_en = 1; 
                vsrc2_en = 1;
                read3_en = 0;
            end 
            VMUL: begin  
                write_reg_en = 1;
                sram_en = 0; 
                sram_func_en = 0;
                reduction_en = 0;
                sparsity_en = 1;
                writeback_sel = 2'b01;
                alu_en = 1; 
                vsrc2_en = 1;
                read3_en = 0;
            end 
            VMAC: begin 
                write_reg_en = 1;
                sram_en = 0; 
                sram_func_en = 0;
                reduction_en = 0;
                sparsity_en = 1;
                writeback_sel = 2'b01;
                alu_en = 1; 
                vsrc2_en = 1;
                read3_en = 1;
            end 
            VDOT: begin 
                write_reg_en = 1;
                sram_en = 0; 
                sram_func_en = 0;
                reduction_en = 1;
                sparsity_en = 1;
                writeback_sel = 2'b10;
                alu_en = 1; 
                vsrc2_en = 1;
                read3_en = 0;
            end 
            VRELU: begin 
                write_reg_en = 1;
                sram_en = 0; 
                sram_func_en = 0;
                reduction_en = 0;
                sparsity_en = 0;
                writeback_sel = 2'b01;
                alu_en = 1; 
                vsrc2_en = 0;
                read3_en = 0;
            end
            VLOAD: begin
                write_reg_en = 1;
                sram_en = 1; 
                sram_func_en = 0;
                reduction_en = 0;
                sparsity_en = 0;
                writeback_sel = 2'b00;
                alu_en = 0; 
                vsrc2_en = 0;
                read3_en = 0; 
            end 
            VSTORE: begin 
                write_reg_en = 0;
                sram_en = 1; 
                sram_func_en = 1;
                reduction_en = 0;
                sparsity_en = 0;
                writeback_sel = 2'b00;
                alu_en = 0; 
                vsrc2_en = 1;
                read3_en = 0;
            end
            default: begin
                write_reg_en = 0;
                sram_en = 0; 
                sram_func_en = 0;
                reduction_en = 0;
                sparsity_en = 0;
                writeback_sel = 2'b00;
                alu_en = 0; 
                vsrc2_en = 0;
                read3_en = 0; 
            end   
        endcase 
    end 
endmodule 