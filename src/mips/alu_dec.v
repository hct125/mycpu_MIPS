`timescale 1ns / 1ps
//根据op码和funct码解码，输出对应的alu control信号
`include "defines2.vh"
module alu_dec(
    input wire [5:0] funct,
    input wire [3:0] op,
    output reg [4:0] alucontrol
);

// assign alucontrol = (op == 3'b000)? `ALU_ADD : //lw sw addi addiu
always @(*) begin
    case(op)
        `R_TYPE_OP: begin
                case(funct)
                    `ADD: alucontrol <= `ADD_CONTROL;
                    `ADDU: alucontrol <= `ADDU_CONTROL;
                    `SUB: alucontrol <= `SUB_CONTROL;
                    `SUBU: alucontrol <= `SUBU_CONTROL;
                    `SLT: alucontrol <= `SLT_CONTROL;
                    `SLTU: alucontrol <= `SLTU_CONTROL;
                    `SLL: alucontrol <= `SLL_CONTROL;
                    `SRL: alucontrol <= `SRL_CONTROL; 
                    `SRA: alucontrol <= `SRA_CONTROL; 
                    `SLLV: alucontrol <= `SLLV_CONTROL; 
                    `SRLV: alucontrol <= `SRLV_CONTROL; 
                    `SRAV: alucontrol <= `SRAV_CONTROL; 
                    `AND: alucontrol <= `AND_CONTROL; 
                    `OR: alucontrol <= `OR_CONTROL;
                    `XOR: alucontrol <= `XOR_CONTROL; 
                    `NOR: alucontrol <= `NOR_CONTROL;
                    `MULT: alucontrol <= `MULT_CONTROL;
                    `MULTU: alucontrol <= `MULTU_CONTROL;
                    `DIV: alucontrol <= `DIV_CONTROL;
                    `DIVU: alucontrol <= `DIVU_CONTROL;
                    // 4条数据移动指令
                    `MFHI: alucontrol <= `MFHI_CONTROL;
                    `MFLO: alucontrol <= `MFLO_CONTROL;
                    `MTHI: alucontrol <= `MTHI_CONTROL;
                    `MTLO: alucontrol <= `MTLO_CONTROL;
                    default: alucontrol <= 5'b00000;
                endcase
        end
        `ORI_OP: alucontrol <= `OR_CONTROL;
        `ANDI_OP: alucontrol <= `AND_CONTROL;
        `XORI_OP: alucontrol <= `XOR_CONTROL;
        `LUI_OP: alucontrol <= `LUI_CONTROL;
        `ADDI_OP: alucontrol <= `ADD_CONTROL;
        `ADDIU_OP: alucontrol <= `ADDU_CONTROL;
        `SLTI_OP: alucontrol <= `SLT_CONTROL;
        `SLTIU_OP: alucontrol <= `SLTU_CONTROL;
        `MEM_OP: alucontrol <= `ADD_CONTROL;
        `USELESS_OP: alucontrol <= 5'b00000;
        default: alucontrol <= 5'b00000;
    endcase
end

                                
endmodule
