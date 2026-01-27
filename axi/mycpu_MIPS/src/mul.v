`timescale 1ns / 1ps
`include "defines2.vh"

module mul(
    input [31:0] a,
    input [31:0] b,
    input [4:0] op, //运算符控制码
    output [63:0] result
    );

    reg [63:0] result_reg;

    always @(*) begin                                        
        case(op)
            `MULT_CONTROL: result_reg = $signed({{32{a[31]}}, a}) * $signed({{32{b[31]}}, b});  //有符号乘法，高位符号扩展
            `MULTU_CONTROL: result_reg = {32'b0, a} * {32'b0, b}; //无符号乘法，高位补0
            default: result_reg = 64'b0;
        endcase
    end

    assign result = result_reg;

endmodule
