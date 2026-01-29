`timescale 1ns / 1ps
/* Main Decoder - 主译码器
   功能：根据op, rs, rt, funct 解码出jump, regwrite, regdst等控制信号和aluop
   兼容性：支持 Arithmetic分支的算术指令集 + HEAD分支的复杂跳转/分支指令 + 特权指令
   Sigs宽度：9位 [jump, regwrite, regdst, alusrc, branch, memwrite, memtoreg, data_ram_ena, sext]
*/
`include "defines2.vh"

module main_dec(
    input wire [5:0] op,
    input wire [4:0] rs,        // 用于COP0指令区分 MTC0/MFC0/ERET
    input wire [4:0] rt,        // 用于REGIMM指令区分 BLTZ/BGEZ/BLTZAL/BGEZAL
    input wire [5:0] funct,     // 用于R型指令区分 JR/JALR/SYSCALL/BREAK
    output reg [8:0] sigs,      // {jump, regwrite, regdst, alusrc, branch, memwrite, memtoreg, data_ram_ena, sext}
    output reg [3:0] aluop,     // 4位 ALU 操作码
    output reg jal,             // 选择写$31
    output reg link,            // 选择写PC+8
    output reg jr,              // 寄存器跳转
    // CP0 Controls
    output reg cp0we,           // CP0写使能
    output reg cp0re,           // CP0读使能
    output reg syscall,         // SYSCALL指令
    output reg break_inst,      // BREAK指令
    output reg eret,            // ERET指令
    output reg ri               // Reserved Instruction (无效指令)
);

    always@(*)  begin 
        // 默认值
        jal <= 1'b0;
        link <= 1'b0;
        jr <= 1'b0;
        cp0we <= 1'b0;
        cp0re <= 1'b0;
        syscall <= 1'b0;
        break_inst <= 1'b0;
        eret <= 1'b0;
        ri <= 1'b0;
        
        case(op)
            `R_TYPE: begin
                case(funct)
                    `JR: begin // JR
                        sigs <= 9'b100000000;
                        aluop <= `USELESS_OP;
                        jr <= 1'b1;
                    end
                    `JALR: begin // JALR - 写入rd而不是$31
                        sigs <= 9'b111000000; // regdst=1 选择rd
                        aluop <= `USELESS_OP;
                        jal <= 1'b0;      // 不选择$31！JALR写rd
                        link <= 1'b1;     // 写PC+8
                        jr <= 1'b1;       // 寄存器跳转
                    end
                    `SYSCALL: begin
                        sigs <= 9'b000000000;
                        aluop <= `USELESS_OP;
                        syscall <= 1'b1;
                    end
                    `BREAK: begin
                        sigs <= 9'b000000000;
                        aluop <= `USELESS_OP;
                        break_inst <= 1'b1;
                    end
                    default: begin   // 普通R型 (ADD, SUB, SLT, DIV等)
                        sigs <= 9'b011000001;
                        aluop <= `R_TYPE_OP;
                    end
                endcase
            end
            
            `SPECIAL3_INST: begin // MTC0, MFC0, ERET (op = 6'b010000)
                case(rs)
                    `MTC0: begin
                        // MTC0: rt -> CP0[rd]
                        // regdst=1 so wa3 tracks 'rd' (CP0 addr)
                        // regwrite=0
                        sigs <= 9'b001000000; // regdst=1
                        aluop <= `MTC0_OP; 
                        cp0we <= 1'b1;
                    end
                    `MFC0: begin
                        // MFC0: rt <- CP0[rd]
                        sigs <= 9'b010000000; // regwrite=1
                        cp0re <= 1'b1;
                        aluop <= `MFC0_OP;
                    end
                    `ERET: begin
                        sigs <= 9'b000000000;
                        eret <= 1'b1;
                        aluop <= `USELESS_OP;
                    end
                    default: begin
                        sigs <= 9'b000000000;
                        aluop <= `USELESS_OP;
                        ri <= 1'b1; // COP0 无效指令
                    end
                endcase
            end

            `LW: begin     // lw
                sigs <= 9'b010100111; // {0,1,0,1,0,0,1,1,1} -> regwrite, alusrc, memtoreg, ram_en, sext
                aluop <= `MEM_OP;
            end
            
            `SW: begin     // sw
                sigs <= 9'b000101011; // {0,0,0,1,0,1,0,1,1} -> alusrc, memwrite, ram_en, sext
                aluop <= `MEM_OP;
            end

            `LB, `LBU, `LH, `LHU: begin // lb, lbu, lh, lhu
                sigs <= 9'b010100111; // Same as LW
                aluop <= `MEM_OP;
            end

            `SB, `SH: begin     // sb, sh
                sigs <= 9'b000101011; // Same as SW
                aluop <= `MEM_OP;
            end
            
            `BEQ: begin     // beq
                sigs <= 9'b000010001; // {0,0,0,0,1,0,0,0,1} -> branch, sext
                aluop <= `USELESS_OP;
            end
            
            `BNE: begin     // bne
                sigs <= 9'b000010001; 
                aluop <= `USELESS_OP; // 分支判定是在 D 阶段,ALU 计算出的结果实际上是被丢弃的
            end
            
            `BLEZ: begin    // blez
                sigs <= 9'b000010001;
                aluop <= `USELESS_OP;
            end
            
            `BGTZ: begin    // bgtz
                sigs <= 9'b000010001;
                aluop <= `USELESS_OP;
            end
            
            `REGIMM_INST: begin // REGIMM (BLTZ, BGEZ, BLTZAL, BGEZAL)
                case(rt)
                    `BLTZ, `BGEZ: begin 
                        sigs <= 9'b000010001;
                        aluop <= `USELESS_OP;
                    end
                    `BLTZAL, `BGEZAL: begin
                        // 既是分支又是跳转链接
                        // 需要写寄存器(link)
                        sigs <= 9'b010010001; // regwrite=1, branch=1, sext=1
                        aluop <= `USELESS_OP;
                        jal <= 1'b1;  // 写$31
                        link <= 1'b1; // 写PC+8
                    end
                    default: begin
                        sigs <= 9'b000000000;
                        aluop <= `USELESS_OP;
                        ri <= 1'b1; // REGIMM 无效指令
                    end
                endcase
            end

            `ADDI: begin    // addi
                sigs <= 9'b010100001; // regwrite, alusrc, sext
                aluop <= `ADDI_OP;
            end
            
            `ADDIU: begin   // addiu
                sigs <= 9'b010100001;
                aluop <= `ADDIU_OP;
            end
            
            `ORI: begin     // ori (无符号扩展)
                sigs <= 9'b010100000; // sext=0
                aluop <= `ORI_OP;
            end
            
            `ANDI: begin     // andi (无符号扩展)
                sigs <= 9'b010100000; // sext=0
                aluop <= `ANDI_OP;
            end

            `XORI: begin     // xori (无符号扩展)
                sigs <= 9'b010100000; // sext=0
                aluop <= `XORI_OP;
            end

            `LUI: begin     // lui
                sigs <= 9'b010100000; // sext=0
                aluop <= `LUI_OP;
            end
            
            `SLTI: begin    // slti
                sigs <= 9'b010100001;
                aluop <= `SLTI_OP;
            end
            
            `SLTIU: begin   // sltiu
                sigs <= 9'b010100001;
                aluop <= `SLTIU_OP;
            end
            
            `J: begin       // j
                sigs <= 9'b100000001; // jump
                aluop <= `USELESS_OP;
            end
            
            `JAL: begin     // jal
                sigs <= 9'b110000001; // jump, regwrite
                aluop <= `USELESS_OP; // ALU不需要做操作，地址计算在ID级
                jal <= 1'b1;
                link <= 1'b1;
            end
            
            default: begin
                sigs <= 9'b000000000;
                aluop <= `USELESS_OP;
                ri <= 1'b1; // 无效 opcode
            end
        endcase
    end
endmodule
