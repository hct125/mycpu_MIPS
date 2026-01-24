`timescale 1ns / 1ps

module tb_top();

reg clk, resetn;

//iverilog 波形文件生成
initial begin
$dumpfile("wave.vcd"); // 指定波形文件为dump.vcd
$dumpvars(0, tb_top); // 记录tb_top模块下所有信号
end

initial
begin
    clk = 1'b0;
    resetn = 1'b0;
    #100;
    resetn = 1'b1;

    #10000;
    $finish;
end
always #5 clk=~clk;

top soc(
    .clk(clk),
    .resetn(resetn)
);

endmodule