`timescale 1ns / 1ps
`include "defines2.vh"

// HI/LO寄存器模块 - 按照参考实现重写
// 使用单一写使能，在M阶段写入
module hilo_reg(
    input wire clk,
    input wire rst,
    input wire we,              // 写使能（M阶段，已经被flushM gate过）
    input wire [31:0] hi_i,     // 要写入HI的值
    input wire [31:0] lo_i,     // 要写入LO的值
    output reg [31:0] hi_o,     // HI输出
    output reg [31:0] lo_o      // LO输出
);

    // 参考实现使用下降沿写入
    always @(negedge clk) begin
        if (rst) begin
            hi_o <= 0;
            lo_o <= 0;
        end else if (we) begin
            hi_o <= hi_i;
            lo_o <= lo_i;
        end
    end
endmodule
