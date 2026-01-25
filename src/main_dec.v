`timescale 1ns / 1ps
// Main Decoder - 主译码器
// sigs: {jump, regwrite, regdst, alusrc, branch, memwrite, memtoreg, data_ram_ena}
// 支持逻辑运算指令（AND/ANDI/OR/ORI/XOR/XORI/NOR/LUI）和移位指令（SLL/SRL/SRA/SLLV/SRLV/SRAV）

module main_dec(
    input wire [5:0] op,
    input wire [4:0] rt,        // 用于BRANCHS指令区分BLTZ/BGEZ/BLTZAL/BGEZAL
    input wire [5:0] funct,     // 用于R型指令区分JR/JALR
    output reg [7:0]sigs,       // {jump, regwrite, regdst, alusrc, branch, memwrite, memtoreg, data_ram_ena}
    output wire [2:0] aluop,    // 扩展到3位
    output wire jal,            // 选择写$31
    output wire link,           // 选择写PC+8
    output wire jr,             // 寄存器跳转
    output wire zero_ext        // 零扩展选择（用于ANDI/ORI/XORI/LUI）
);
    reg [2:0] aluop_reg;        // 扩展到3位
    reg jal_reg, link_reg, jr_reg;
    reg zero_ext_reg;
    assign aluop = aluop_reg;
    assign jal = jal_reg;
    assign link = link_reg;
    assign jr = jr_reg;
    assign zero_ext = zero_ext_reg;
    
    always@(*)  begin 
        // 默认值
        jal_reg <= 1'b0;
        link_reg <= 1'b0;
        jr_reg <= 1'b0;
        zero_ext_reg <= 1'b0;   // 默认符号扩展
        
        case(op)
            6'b000000:begin     //R-TYPE (包含逻辑运算和移位指令)
                case(funct)
                    6'b001000: begin // JR
                        sigs <= 8'b10000000;
                        aluop_reg <= 3'b000;
                        jr_reg <= 1'b1;
                    end
                    6'b001001: begin // JALR - 写入rd而不是$31
                        sigs <= 8'b11100000;  // regdst=1 选择rd
                        aluop_reg <= 3'b000;
                        jal_reg <= 1'b0;      // 不选择$31！JALR写rd
                        link_reg <= 1'b1;     // 写PC+8
                        jr_reg <= 1'b1;       // 寄存器跳转
                    end
                    default: begin   // 其他R型（包含AND/OR/XOR/NOR/SLL/SRL/SRA/SLLV/SRLV/SRAV等）
                        sigs <= 8'b01100000;  // regwrite=1, regdst=1(写rd)
                        aluop_reg <= 3'b010;  // R-TYPE
                    end
                endcase
            end
            6'b100011:begin     //lw
                sigs <= 8'b01010011;
                aluop_reg <= 3'b000;  // ADD
            end
            6'b101011:begin     //sw
                sigs <= 8'b00010101;
                aluop_reg <= 3'b000;  // ADD
            end
            6'b000100:begin     //beq
                sigs <= 8'b00001000;
                aluop_reg <= 3'b110;  // 分支指令用SUB
            end
            6'b000101:begin     //bne
                sigs <= 8'b00001000;
                aluop_reg <= 3'b110;
            end
            6'b000110:begin     //blez
                sigs <= 8'b00001000;
                aluop_reg <= 3'b110;
            end
            6'b000111:begin     //bgtz
                sigs <= 8'b00001000;
                aluop_reg <= 3'b110;
            end
            6'b000001:begin     //BRANCHS (BLTZ, BGEZ, BLTZAL, BGEZAL)
                case(rt)
                    5'b00000, 5'b00001: begin // BLTZ, BGEZ
                        sigs <= 8'b00001000;
                        aluop_reg <= 3'b110;
                    end
                    5'b10000, 5'b10001: begin // BLTZAL, BGEZAL
                        sigs <= 8'b10001000;
                        aluop_reg <= 3'b110;
                        jal_reg <= 1'b1;
                        link_reg <= 1'b1;
                    end
                    default: begin
                        sigs <= 8'b00000000;
                        aluop_reg <= 3'b000;
                    end
                endcase
            end
            6'b001000:begin     //addi
                sigs <= 8'b01010000;
                aluop_reg <= 3'b000;  // ADD
            end
            6'b001001:begin     //addiu
                sigs <= 8'b01010000;
                aluop_reg <= 3'b000;  // ADD
            end
            // ========== 逻辑运算I型指令（新增）==========
            6'b001100:begin     //andi (零扩展)
                sigs <= 8'b01010000;  // regwrite=1, regdst=0(rt), alusrc=1(立即数)
                aluop_reg <= 3'b011;  // AND
                zero_ext_reg <= 1'b1; // 零扩展
            end
            6'b001101:begin     //ori (零扩展)
                sigs <= 8'b01010000;
                aluop_reg <= 3'b001;  // OR
                zero_ext_reg <= 1'b1; // 零扩展
            end
            6'b001110:begin     //xori (零扩展)
                sigs <= 8'b01010000;
                aluop_reg <= 3'b100;  // XOR
                zero_ext_reg <= 1'b1; // 零扩展
            end
            6'b001111:begin     //lui (立即数放高16位)
                sigs <= 8'b01010000;  // regwrite=1, regdst=0(rt), alusrc=1(立即数)
                aluop_reg <= 3'b101;  // LUI
                zero_ext_reg <= 1'b1; // 零扩展（LUI不关心低16位）
            end
            // ========== 跳转指令 ==========
            6'b000010:begin     //j
                sigs <= 8'b10000000;
                aluop_reg <= 3'b000;
            end
            6'b000011:begin     //jal
                sigs <= 8'b11000000;
                aluop_reg <= 3'b000;
                jal_reg <= 1'b1;
                link_reg <= 1'b1;
            end
            default:begin
                sigs <= 8'b00000000;
                aluop_reg <= 3'b000;
            end
        endcase
    end
endmodule
