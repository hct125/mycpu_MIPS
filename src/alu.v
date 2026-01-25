`timescale 1ns / 1ps
//ALU模块
`include "defines2.vh"
module alu(
    input [31:0] a, //A端口
    input [31:0] b, //B端口
    input [4:0] sa, //移位量
    input [4:0] op, //运算符控制码
    output reg [31:0] result,  //结果
    output reg overflow, //溢出标志
    output wire zero
    );

    always @(*) begin
        overflow = 1'b0;
        case(op)
            `ADD_CONTROL: begin
                result = a + b;
                overflow = (a[31] == b[31]) && (result[31] != a[31]);
            end
            `ADDU_CONTROL: result = a + b;
            `SUB_CONTROL: begin
                result = a - b;
                overflow = (a[31] != b[31]) && (result[31] != a[31]);
            end
            `SUBU_CONTROL: result = a - b;
            `AND_CONTROL: result = a & b;
            `OR_CONTROL: result = a | b;
            `XOR_CONTROL: result = a ^ b;
            `NOR_CONTROL: result = ~(a | b);
            `LUI_CONTROL: result = b << 16;
            `SLL_CONTROL: result = b << sa;
            `SRL_CONTROL: result = b >> sa;
            `SRA_CONTROL: result = $signed(b) >>> sa;
            `SLLV_CONTROL: result = b << a[4:0];
            `SRLV_CONTROL: result = b >> a[4:0];
            `SRAV_CONTROL: result = $signed(b) >>> a[4:0];
            `SLT_CONTROL: result = $signed(a) < $signed(b) ? 1 : 0;
            `SLTU_CONTROL: result = a < b ? 1 : 0;
            
            default: result = 32'b0;
        endcase
    end
    assign zero = (result == 32'b0);
endmodule
