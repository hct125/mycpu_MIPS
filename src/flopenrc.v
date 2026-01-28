`timescale 1ns / 1ps
//含有rst、en和clear功能的寄存器模块
// 修正：clear优先级高于en（与参考实现一致）
module flopenrc #(parameter WIDTH = 8)(
    input wire clk,rst,en,clear,
    input wire[WIDTH-1:0] d,
    output reg[WIDTH-1:0] q
);
    always @(posedge clk) begin
        if(rst) begin
            q <= 0;
        end else if(clear) begin
            // clear优先级高于en，确保异常flush时即使有stall也能清零
            q <= 0;
        end else if(en) begin
            q <= d;
        end
        // 当en=0且clear=0时，q保持不变
    end
endmodule
