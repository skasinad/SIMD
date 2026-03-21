/*
This will store alll the 16 registers into essentially one array and each register has 64 bits.

See my register has to essentially read data from registers that we identify through their mem address, write data into registers that we identfy through mem address... these mem addresses another component is telling

Coming to actually reading and writing the data... writing the data into the specified register in the file is the first thing and also being able to read out of a specific register from the file is the next

enable is just going to tell me whether the register file should even write out to a register b/c we have instructions like 
VSTORE which legit dont write anything into another register... yes even if it is just one instruction I included an enable...



anything about the numbers I chose you can find in the microarchitecture file in the docs folder... plz read it b/c I kept in lots of work ideating it :)

3 reading ports and 1 writing port... i mean i didnt see a need for more writing ports? Mainly b/c my instructions are outputting to one register at all times

*/


module registers#(
    parameter int TOTAL = 16,
    parameter int SIZE = 64
) (
    input logic clk,
    input logic rst, 
    input logic enable,

    input logic[3:0] rd_address1,
    input logic[3:0] rd_address2, 
    input logic[3:0] rd_address3, 
    
    input logic[3:0] wt_address,
    input logic[SIZE-1:0] wt_data, 
    

    output logic[SIZE-1:0] rd_data1,
    output logic[SIZE-1:0] rd_data2,
    output logic[SIZE-1:0] rd_data3
);

    //each register is of 64 bits and there are 16 of them total
    logic[SIZE-1:0] file[TOTAL-1:0];

    always_ff @(posedge clk) begin 
        if (rst) begin 
            for(int i = 0; i<TOTAL; i++) begin
                file[i] <= 0; 
            end
        end  
        else begin   
            if(enable)
                file[wt_address] <= wt_data;
            
            //I kept the reading stuff outside the if enable b/c enable is only for writing logic
            rd_data1 <= file[rd_address1];
            rd_data2 <= file[rd_address2];
            rd_data3 <= file[rd_address3];
        end 
    end 

endmodule 