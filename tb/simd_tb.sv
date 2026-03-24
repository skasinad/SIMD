/*
pretty straightforward stuff just a normal testbench for my full SIMD module
*/

module simd_tb;
logic clk;
logic rst;
logic valid;

logic[15:0] instruction;
logic [63:0] result; 
logic[31:0] scalar;

//DUT
simd dut (
    .clk(clk),
    .rst(rst),
    .instruction(instruction),
    .result(result),
    .scalar(scalar),
    .valid(valid)
);
initial clk = 0; 
always #5 clk = ~clk;

//localparams for each instruction opcodes
localparam logic[2:0] VADD = 3'b0;
localparam logic[2:0] VMUL = 3'b001;
localparam logic[2:0] VMAC = 3'b010;
localparam logic[2:0] VDOT = 3'b011;
localparam logic[2:0] VRELU = 3'b100;
localparam logic[2:0] VLOAD = 3'b101;
localparam logic[2:0] VSTORE = 3'b110;

//now for the test
//just for debugging purposes im going to keep 3 clock edges in between my instructions, just 1 extra clock cycle to read what is going on
initial begin 
    rst = 1; 
    instruction = 16'b0;
    @(posedge clk);
    @(posedge clk);
    @(posedge clk);
    rst = 0;
    @(posedge clk); //hopefully it fixes it...

    //first is sram ofc to load test data
    dut.memory.srambuff[0] = 64'h0807060504030201; //jist 8 INT8s of [2, 3, 4, 5, 6, 7, 8]
    dut.memory.srambuff[1] = 64'h0908070605040302; //[-1, 2, -3, 4, -5, 6, -7, 8] for VRELU
    //sparsity...
    dut.memory.srambuff[2] = 64'h08F906FB04FD02FF;

    dut.memory.srambuff[3] = 64'h0800060004000200;

    //next to push the data into the registers
    instruction = {VLOAD, 4'd1, 4'd0, 4'd0, 1'b0};
    @(posedge clk);
    @(posedge clk);
    @(posedge clk); 

    //some debugging stuff bc im getting all 0s...
    /*$display("DEBUGGING SRAM[0]: %h", dut.memory.srambuff[0]);
    $display("DEBUGGING rd_memory: %h", dut.rd_memory);
    $display("DEBUGGING wt_data: %h", dut.wt_data);
    $display("DEBUGGING write_reg_en: %b", dut.write_reg_en);
    $display("DEBUGGING writeback_sel: %b", dut.writeback_sel);
    $display("DEBUGGING v1: %h", dut.simdreg.file[1]);
    */
    

    //not sure why its still 0, i think its maybe an issue with my SRAM bc im loading stuff before the rst, so maybe an extra clock signal???

    instruction = {VLOAD, 4'd2, 4'd1, 4'd0, 1'b0};
    @(posedge clk); 
    @(posedge clk);
    @(posedge clk);
    instruction = {VLOAD, 4'd3, 4'd2, 4'd0, 1'b0};
    @(posedge clk);
    @(posedge clk);
    @(posedge clk);
    instruction = {VLOAD, 4'd4, 4'd3, 4'd0, 1'b0};
    @(posedge clk);
    @(posedge clk);
    @(posedge clk);

    //finally first test, VADD
    //vec5 = vec1 + vec2
    instruction = {VADD, 4'd5, 4'd1, 4'd2, 1'b0};
    @(posedge clk);
    @(posedge clk);
    @(posedge clk);
    $display("vec5 = vec1 + vec2: %h", result);
    
    //VMUL test vec6 = vec1*vec2
    instruction = {VMUL, 4'd6, 4'd1, 4'd2, 1'b0};
    @(posedge clk);
    @(posedge clk);
    @(posedge clk);
    $display("vec6 = vec1 * vec2: %h", result);

    //VMAC - Vec7 = vec7 + (vec1 * vec2)
    instruction = {VMAC, 4'd7, 4'd1, 4'd2, 1'b0};
    @(posedge clk);
    @(posedge clk);
    @(posedge clk);
    $display("vec7 = vec7 + (vec1 * vec2): %h", result);

    //next test VDOT
    // v1.v2 = 1*2 + 2*3 + 3*4 + 4*5 + 5*6 + 6*7 + 7*8 + 8*9
    instruction = {VDOT, 4'd8, 4'd1, 4'd2, 1'b0};
    @(posedge clk);
    @(posedge clk);
    @(posedge clk);
    $display("VDOT, should be 240: %0d", scalar);

    //VRELU and vec3 will be used
    instruction = {VRELU, 4'd9, 4'd3, 4'd0, 1'b0};
    @(posedge clk);
    @(posedge clk);
    @(posedge clk);
    $display("VRELU on vector 3: %h", result);


    //sparsity test
    instruction = {VMUL, 4'd10, 4'd1, 4'd4, 1'b0};
    @(posedge clk);
    @(posedge clk);
    @(posedge clk);
    $display("sparsity check: %h", result);

    
    //just one VSTORE test for memory
    //maybe like storing vec5 to 4th address
    instruction = {VSTORE, 4'd0, 4'd4, 4'd5, 1'b0};
    @(posedge clk);
    @(posedge clk);
    @(posedge clk);
    $display("VSTORE memory[4]: %h", dut.memory.srambuff[4]);


    //RESET
    instruction = 16'b0;
    @(posedge clk);
    @(posedge clk);
    @(posedge clk);
    $display("Reset successful. Tests complete :)");
    $finish;



end 


endmodule 