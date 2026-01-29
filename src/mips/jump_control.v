`timescale 1ns / 1ps
// 跳转控制模块 - 处理J/JAL/JR/JALR指令

module jump_control (
    input wire [31:0] instrD,
    input wire [31:0] pcplus4D,
    input wire [31:0] srcaD,  // rs寄存器的值（可能转发）
    input wire regwriteE, regwriteM,
    input wire [4:0] writeregE, writeregM,

    output wire jumpD,          // 需要跳转
    output wire jump_conflictD, // 跳转冲突（JR/JALR的rs有数据冒险）
    output wire [31:0] pcjumpD  // 跳转目标地址
);
    wire jr, j;
    wire [4:0] rsD;
    
    assign rsD = instrD[25:21];
    
    // 判断指令类型
    // JR: opcode=000000, funct=001000
    // JALR: opcode=000000, funct=001001
    // J: opcode=000010
    // JAL: opcode=000011
    assign jr = (instrD[31:26] == 6'b000000) && 
                ((instrD[5:0] == 6'b001000) || (instrD[5:0] == 6'b001001));
    assign j = (instrD[31:26] == 6'b000010) || (instrD[31:26] == 6'b000011);
    
    assign jumpD = jr | j;

    // Jump冲突：JR/JALR的rs寄存器在E阶段需要写回（需要stall）
    // M阶段可以转发，不需要stall
    assign jump_conflictD = jr && (
        (regwriteE && (rsD == writeregE) && (rsD != 0))
    );
    
    // 跳转目标地址
    wire [31:0] pcjump_imm;
    assign pcjump_imm = {pcplus4D[31:28], instrD[25:0], 2'b00};
    assign pcjumpD = j ? pcjump_imm : srcaD;  // J/JAL用立即数，JR/JALR用寄存器值

endmodule
