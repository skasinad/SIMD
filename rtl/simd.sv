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

    //step 1 fetch and decode
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

    logic[63:0] wt_data;
    registers simdreg (
        .clk(clk),
        .rst(rst),
        .enable(write_reg_en),
        .rd_address1(vsrc1),
        .rd_address2(vsrc2),
        .rd_address3(vdst),
        .wt_address(vdst),
        .wt_data(wt_data),
        .rd_data1(rd_data1),
        .rd_data2(rd_data2),
        .rd_data3(rd_data3)
    );

    //step 2 is sparsity check

    //same approach just making some more internal wires to pack 64 bits into each 8 bit again
    wire[7:0] operand1[7:0];
    wire[7:0] operand2[7:0];
    assign operand1[0] = rd_data1[7:0];
    assign operand1[1] = rd_data1[15:8];
    assign operand1[2] = rd_data1[23:16];
    assign operand1[3] = rd_data1[31:24];
    assign operand1[4] = rd_data1[39:32];
    assign operand1[5] = rd_data1[47:40];
    assign operand1[6] = rd_data1[55:48];
    assign operand1[7] = rd_data1[63:56];
    assign operand2[0] = rd_data2[7:0];
    assign operand2[1] = rd_data2[15:8];
    assign operand2[2] = rd_data2[23:16];
    assign operand2[3] = rd_data2[31:24];
    assign operand2[4] = rd_data2[39:32];
    assign operand2[5] = rd_data2[47:40];
    assign operand2[6] = rd_data2[55:48];
    assign operand2[7] = rd_data2[63:56];


     sparsity sparsityfinal (
        .clk(clk),
        .rst(rst),
        .opcode(opcode),
        .oper1(operand1),
        .oper2(operand2),
        .buffer(sparsitybuff)
    );

    sram memory (
        .clk(clk),
        .rst(rst),
        .enable(sram_func_en),
        .address(vsrc1), //address will ALWAYS be in vsrc1
        .wt_dt_memory(rd_data2),
        .rd_memory(rd_memory)
    );


    //execution!!!
    //I actually need 8 seperate slices bc I need to represent each slice 
    //tried keeping this all into a genvar but genuinely couldnt think of the logic at the moment
    slice slice1 (
        .clk(clk),
        .rst(rst),
        .enable(alu_en & sparsitybuff[0]),
        .num1(rd_data1[7:0]),
        .num2(rd_data2[7:0]),
        .acum(rd_data3[7:0]),
        .opcode(opcode),
        .value(value[0])
    );
    slice slice2 (
        .clk(clk),
        .rst(rst),
        .enable(alu_en & sparsitybuff[1]),
        .num1(rd_data1[15:8]),
        .num2(rd_data2[15:8]),
        .acum(rd_data3[15:8]),
        .opcode(opcode),
        .value(value[1])
    );

    slice slice3 (
        .clk(clk),
        .rst(rst),
        .enable(alu_en & sparsitybuff[2]),
        .num1(rd_data1[23:16]),
        .num2(rd_data2[23:16]),
        .acum(rd_data3[23:16]),
        .opcode(opcode),
        .value(value[2])
    );

    slice slice4 (
        .clk(clk),
        .rst(rst),
        .enable(alu_en & sparsitybuff[3]),
        .num1(rd_data1[31:24]),
        .num2(rd_data2[31:24]),
        .acum(rd_data3[31:24]),
        .opcode(opcode),
        .value(value[3])
    );

    slice slice5 (
        .clk(clk),
        .rst(rst),
        .enable(alu_en & sparsitybuff[4]),
        .num1(rd_data1[39:32]),
        .num2(rd_data2[39:32]),
        .acum(rd_data3[39:32]),
        .opcode(opcode),
        .value(value[4])
    );

    slice slice6 (
        .clk(clk),
        .rst(rst),
        .enable(alu_en & sparsitybuff[5]),
        .num1(rd_data1[47:40]),
        .num2(rd_data2[47:40]),
        .acum(rd_data3[47:40]),
        .opcode(opcode),
        .value(value[5])
    );

    slice slice7 (
        .clk(clk),
        .rst(rst),
        .enable(alu_en & sparsitybuff[6]),
        .num1(rd_data1[55:48]),
        .num2(rd_data2[55:48]),
        .acum(rd_data3[55:48]),
        .opcode(opcode),
        .value(value[6])
    );

    slice slice8 (
        .clk(clk),
        .rst(rst),
        .enable(alu_en & sparsitybuff[7]),
        .num1(rd_data1[63:56]),
        .num2(rd_data2[63:56]),
        .acum(rd_data3[63:56]),
        .opcode(opcode),
        .value(value[7])
    );

    //step 4 - reduction + writeback
    reductiontree reducted(
        .opcode(opcode),
        .slicebuffer(value),
        .scalar(reductiontree_out)
    );

    //writeback data as MUX for 3 sources to one destination
    always_comb begin
        case(writeback_sel)
            2'b00: wt_data =  rd_memory;
            2'b01: wt_data = fullslice; 
            2'b10: wt_data = reductiontree_out;
            default: wt_data = 64'b0;
        endcase  
    end

    //finally.. setting the wires to the outputs
    assign result = wt_data;
    assign scalar = reductiontree_out;
    assign valid = write_reg_en;

endmodule 