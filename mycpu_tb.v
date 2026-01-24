`timescale 1ns / 1ps

module tb_top();
    reg clk, reset;
    reg [9:0] pc;
    reg [31:0] alu_result,readdata,writedata,instr;
    reg [31:0] count;
    reg [39:0] ascii;

    //iverilog仿真波形生成
    initial begin
    $dumpfile("wave.vcd"); // 指定波形文件为dump.vcd
    $dumpvars(0, tb_top); // 记录tb_top模块下所有信号
    end

    initial
    begin
        clk = 1'b0;
        reset = 1'b0;
        count=32'b0;
        #100;
        reset = 1'b1;

        #3000;
        $finish;
    end
    always #5 clk=~clk;

    always@(posedge clk)
    begin
        if (reset) begin
            count <= count + 1;
            if (count<=70)
                $display("pc=%h",pc,",instr=%h",instr,", alu_result=%h",alu_result);
        end
    end

    top soc(
        .clk(clk),
        .reset(reset),
        .pc(pc),
        .alu_result(alu_result),
        .instr(instr),
        .ascii(ascii),
        .readdata(readdata),
        .writedata(writedata)
    );

endmodule