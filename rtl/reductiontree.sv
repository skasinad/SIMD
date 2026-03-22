/*
first level needs to add slice 0 to slice 7 calling it as
p0 = slice 0 + slice 1
p1 = slice 2 + slice 3 
p2 = slice 4 + slice 5
p3 = slice 6 + slice 7

I need to remember to think in terms of VDOT b/c generally the numbers would be diff
with VDOT each slice would alreayd be at 16 bits we r already multiplying the operands

first level each is adding two 16 bit values so the final results need to be 17 bits then
level 2 im just adding 2 17 bits so it should go to 18
level 3 2 18 bits need to be 19.....

i think defining buffers for each level is the way to go
level 3 would just be the scalar output


*/


module reductiontree (
    input logic[2:0] opcode,
    input logic[15:0] slicebuffer [7:0],

    //im keeping the output as 32 bits total nevertheless i explained this reasoning in the architecture
    output logic [31:0] scalar
);
    logic[16:0] leveloneps[3:0];
    logic[17:0] leveltwops[1:0];


    always_comb begin
        if(opcode == 3'b011) begin 
            //first level 1
            leveloneps[0] = slicebuffer[0] + slicebuffer[1];
            leveloneps[1] = slicebuffer[2] + slicebuffer[3];
            leveloneps[2] = slicebuffer[4] + slicebuffer[5];
            leveloneps[3] = slicebuffer[6] + slicebuffer[7];

            //the second level 
            leveltwops[0] = leveloneps[0] + leveloneps[1];
            leveltwops[1] = leveloneps[2] + leveloneps[3];

            //final
            scalar = leveltwops[0] + leveltwops[1];
            end else begin
                scalar = 32'b0; 
            end  
        end  
endmodule 