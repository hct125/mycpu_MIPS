`timescale 1ns / 1ps
//PC寄存器 - AXI版本
// 添加flush输入，用于异常时强制加载新PC（优先级高于en）
module pc(
    input wire clk,rst,en,flush,
    input wire [31:0] din,
    input wire [31:0] newpc,  // 异常入口地址
    output reg [31:0] q
    );
    always @(posedge clk) begin
        if(rst)
            q <= 32'hbfc00000;  // SoC功能测试PC复位地址
        else if(flush)
            q <= newpc;        // 异常时强制跳转，优先级高于en
        else if(en)
            q <= din;
        // else q保持不变
    end
endmodule
