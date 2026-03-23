/*
This is my main simd module where all the other modules I worked on come together in this one

instruction ports would be input in this case

not just delcaring the wires but i need to translate them into the opcode as well

Only input I am really keeping is the instruction b/c that is the one that is externally driven, I think rest I instantiate

Also I am going to keep two outputs one is the regular result other is the scalar output we get, both are the writebacks. 
it can easily break my testbench if i did not keep an output, b/c id need to read the registers internally

*/



module simd # (
    parameter int REGISTER_SIZE = 64
) (
    input logic clk, 
    input logic rst,
    input logic[15:0] instruction,
    
    //writebacks
    output logic[63:0] result, 
    output logic[31:0] scalar,

    //a valid bit so that we know the output is one of the 2 options
    output logic valid 
);
    //internal wires to break the instruction up 

    //instruction
    wire[2:0] opcode = instruction[15:13];
    wire[3:0] vdst = instruction[12:9];
    wire[3:0] vsrc1 = instruction[8:5];
    wire[3:0] vsrc2 = instruction[4:1];
    wire reserved = instruction[0];

    //control signals from the oriignal control module 
    wire write_reg_en;
    wire sram_en;
    wire sram_func_en; 
    wire reduction_en; 
    wire sparsity_en;
    wire[1:0] writeback_sel;
    wire alu_en;
    wire vsrc2_en;
    wire read3_en;

    
    //registers
    wire[REGISTER_SIZE-1:0] rd_data1;
    wire[REGISTER_SIZE-1:0] rd_data2;
    wire[REGISTER_SIZE-1:0] rd_data3;
 

    
    wire[15:0] value[7:0]; //the slices
    wire[7:0] sparsitybuff; //buffer for sparsity
    wire [63:0] rd_memory; //sram output
    wire[31:0] reductiontree_out;

    //gotta take each slice and make it into the total 64 bit value
    wire[63:0] fullslice;
    assign fullslice = {
        value[7][7:0],
        value[6][7:0],
        value[5][7:0],
        value[4][7:0],
        value[3][7:0],
        value[2][7:0],
        value[1][7:0],
        value[0][7:0]
    };

    //instantiating all of it 

    control instant_control (
        .opcode(opcode),
        .write_reg_en(write_reg_en),
        .sram_en(sram_en),
        .sram_func_en(sram_func_en),
        .reduction_en(reduction_en),
        .sparsity_en(sparsity_en),
        .writeback_sel(writeback_sel),
        .alu_en(alu_en),
        .vsrc2_en(vsrc2_en),
        .read3_en(read3_en)
    );

    registers simdreg (
        .rd_data1(rd_data1),
        .rd_data2(rd_data2),
        .rd_data3(rd_data3)
    );

    slice slices (
        .value(value)
    );

    sparsity sparsityfinal (
        .buffer(sparsitybuff)
    );
    
    sram memory (
        .rd_memory(rd_memory)
    );

    reductiontree reducted(
        .scalar(reductiontree_out)
    );

endmodule 