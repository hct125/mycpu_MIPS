`timescale 1ns / 1ps
// ALU模块 - 支持逻辑运算和移位指令
// 操作码定义：
// 4'b0000: AND      4'b0001: OR       4'b0010: ADD      4'b0011: XOR
// 4'b0100: NOR      4'b0101: SLL      4'b0110: SUB      4'b0111: SLT
// 4'b1000: SRL      4'b1001: SRA      4'b1010: LUI      4'b1011: SLLV
// 4'b1100: SRLV     4'b1101: SRAV

module alu(
    input [31:0] a,
    input [31:0] b,
    input [3:0] op,
    input [4:0] shamt,      // 移位量（用于SLL/SRL/SRA）
    output wire [31:0] result,
    output wire zero
);
    assign result = (op == 4'b0000) ? a & b :                           // AND
                    (op == 4'b0001) ? a | b :                           // OR
                    (op == 4'b0010) ? a + b :                           // ADD
                    (op == 4'b0011) ? a ^ b :                           // XOR
                    (op == 4'b0100) ? ~(a | b) :                        // NOR
                    (op == 4'b0101) ? (b << shamt) :                    // SLL (rt << shamt)
                    (op == 4'b0110) ? a - b :                           // SUB
                    (op == 4'b0111) ? {{31{1'b0}}, $signed(a) < $signed(b)} : // SLT (有符号比较)
                    (op == 4'b1000) ? (b >> shamt) :                    // SRL (逻辑右移)
                    (op == 4'b1001) ? ($signed(b) >>> shamt) :          // SRA (算术右移)
                    (op == 4'b1010) ? {b[15:0], 16'b0} :                // LUI (立即数放高16位)
                    (op == 4'b1011) ? (b << a[4:0]) :                   // SLLV (rt << rs[4:0])
                    (op == 4'b1100) ? (b >> a[4:0]) :                   // SRLV (逻辑右移)
                    (op == 4'b1101) ? ($signed(b) >>> a[4:0]) :         // SRAV (算术右移)
                    32'h00000000;
    assign zero = (result == 32'b0);
endmodule
