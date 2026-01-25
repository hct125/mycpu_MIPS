`timescale 1ns / 1ps
// ALU译码器 - 支持逻辑运算和移位指令
// aluop编码：
// 3'b000: ADD (LW/SW/ADDI/ADDIU)
// 3'b001: OR (ORI)
// 3'b010: R-TYPE (根据funct解码)
// 3'b011: AND (ANDI)
// 3'b100: XOR (XORI)
// 3'b101: LUI

module alu_dec(
    input wire [5:0] funct,
    input wire [2:0] op,            // 扩展到3位
    output wire [3:0] alucontrol    // 扩展到4位
);

assign alucontrol = 
    (op == 3'b000) ? 4'b0010 :      // LW/SW/ADDI/ADDIU -> ADD
    (op == 3'b001) ? 4'b0001 :      // ORI -> OR
    (op == 3'b011) ? 4'b0000 :      // ANDI -> AND
    (op == 3'b100) ? 4'b0011 :      // XORI -> XOR
    (op == 3'b101) ? 4'b1010 :      // LUI -> LUI
    (op == 3'b010) ? (              // R-TYPE: 根据funct解码
        // 算术运算
        (funct == 6'b100000) ? 4'b0010 : // ADD
        (funct == 6'b100001) ? 4'b0010 : // ADDU (与ADD相同)
        (funct == 6'b100010) ? 4'b0110 : // SUB
        (funct == 6'b100011) ? 4'b0110 : // SUBU (与SUB相同)
        (funct == 6'b101010) ? 4'b0111 : // SLT
        (funct == 6'b101011) ? 4'b0111 : // SLTU (暂用SLT)
        // 逻辑运算
        (funct == 6'b100100) ? 4'b0000 : // AND
        (funct == 6'b100101) ? 4'b0001 : // OR
        (funct == 6'b100110) ? 4'b0011 : // XOR
        (funct == 6'b100111) ? 4'b0100 : // NOR
        // 移位指令（使用shamt）
        (funct == 6'b000000) ? 4'b0101 : // SLL
        (funct == 6'b000010) ? 4'b1000 : // SRL
        (funct == 6'b000011) ? 4'b1001 : // SRA
        // 移位指令（使用rs）
        (funct == 6'b000100) ? 4'b1011 : // SLLV
        (funct == 6'b000110) ? 4'b1100 : // SRLV
        (funct == 6'b000111) ? 4'b1101 : // SRAV
        4'b0000
    ) : 4'b0000;
                                
endmodule
