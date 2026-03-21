/*
My SRAM but in digital logic implementation this isnt an actual analog design of a SRAM(obviously). Read more in the architecture doc if you have any doubts of why I am doing this

Essentially only 2 instructions are going to be touching my SRAM it is either VLOAD or VSTORE

VLOAD reading: 
-- needs to know which of the 32 locations to read from 
-- then has to keep that 64-bit number whatever it is from the memory into the register

i cant think of anything else VLOAD needs to do...

VSTORE writing: 
-- has to know which of the 32 locations to write to 
-- then should receive the 64 bit data to store
-- has to have permission write 

first 5 bits need to be used to know which location
*/


module sram#(
    parameter int LOCATION = 32, 
    parameter int SIZE = 64
) (
    input logic clk, 
    input logic rst,
    input logic enable, //specifically for write only same idea as register file

    input logic[4:0] address,
    input logic[SIZE-1:0] wt_dt_memory, 
    output logic[SIZE-1:0] rd_memory



);

//very similar this is to register file implementation

    logic[SIZE-1:0] srambuff[LOCATION-1:0];
    
    always_ff @(posedge clk) begin
        if (rst) begin
            for(int i = 0; i < LOCATION; i++) begin
                srambuff[i] <= 0; 
            end  
        end else begin
            if(enable)
                srambuff[address] <= wt_dt_memory;
            rd_memory <= srambuff[address];
            
        end  
    end 


endmodule 