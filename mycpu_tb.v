`timescale 1ns / 1ps

module tb_top();

reg clk, resetn;
reg [31:0] alu_resultM;
reg [31:0] count;

initial begin
$dumpfile("wave.vcd"); // 指定波形文件为dump.vcd
$dumpvars(0, tb_top); // 记录tb_top模块下所有信号
end

initial
begin
    clk = 1'b0;
    resetn = 1'b0;
    count=32'b0;
    #100;
    resetn = 1'b1;

    #3000;
    $finish;
end
always #5 clk=~clk;

always@(posedge clk)
begin
    if (resetn) begin
        count <= count + 1;
        if (count<=50)
            $display("alu_resultM=%h",alu_resultM);
    end
end

top soc(
    .clk(clk),
    .resetn(resetn),
    .alu_resultM(alu_resultM)
);

endmodule