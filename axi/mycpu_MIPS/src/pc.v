`timescale 1ns / 1ps
//PC寄存器
module pc(
    input wire clk,rst,en,
    input wire [31:0] din,
    output reg [31:0] q
    );
    always @(posedge clk) begin
        if(rst) q<=32'hbfc00000;  // SoC功能测试PC复位地址
        else begin
            if(en) q<=din;
            else q<=q;
        end
    end
endmodule
