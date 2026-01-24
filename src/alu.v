`timescale 1ns / 1ps
//ALU模块
`include "defines2.vh"
module alu(
    input [31:0] a, //A端口
    input [31:0] b, //B端口
    input [4:0] sa, //移位量
    input [4:0] op, //运算符控制码
    output reg [31:0] result,  //结果
    output wire zero
    );

    always @(*) begin
        case(op)
            `ADD_CONTROL: result = a + b;
            `ADDU_CONTROL: result = a + b;
            `SUB_CONTROL: result = a - b;
            `SUBU_CONTROL: result = a - b;
            `AND_CONTROL: result = a & b;
            `OR_CONTROL: result = a | b;
            `SLL_CONTROL: result = b << sa;
            `SLT_CONTROL: result = $signed(a) < $signed(b) ? 1 : 0;
            `SLTU_CONTROL: result = a < b ? 1 : 0;
            default: result = 0;
        endcase
    end
    assign zero = (result == 32'b0);
endmodule
