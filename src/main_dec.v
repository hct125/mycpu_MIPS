`timescale 1ns / 1ps
// Main Decoder - 主译码器
// sigs: {jump, regwrite, regdst, alusrc, branch, memwrite, memtoreg, data_ram_ena}

module main_dec(
    input wire [5:0] op,
    input wire [4:0] rt,        // 用于BRANCHS指令区分BLTZ/BGEZ/BLTZAL/BGEZAL
    input wire [5:0] funct,     // 用于R型指令区分JR/JALR
    output reg [7:0]sigs,       // {jump, regwrite, regdst, alusrc, branch, memwrite, memtoreg, data_ram_ena}
    output wire [1:0] aluop,
    output wire jal,            // 选择写$31
    output wire link,           // 选择写PC+8
    output wire jr              // 寄存器跳转
);
    reg [1:0] aluop_reg;
    reg jal_reg, link_reg, jr_reg;
    assign aluop = aluop_reg;
    assign jal = jal_reg;
    assign link = link_reg;
    assign jr = jr_reg;
    
    always@(*)  begin 
        // 默认值
        jal_reg <= 1'b0;
        link_reg <= 1'b0;
        jr_reg <= 1'b0;
        
        case(op)
            6'b000000:begin     //R-TYPE
                case(funct)
                    6'b001000: begin // JR
                        sigs <= 8'b10000000;
                        aluop_reg <= 2'b00;
                        jr_reg <= 1'b1;
                    end
                    6'b001001: begin // JALR - 写入rd而不是$31
                        sigs <= 8'b11100000;  // regdst=1 选择rd
                        aluop_reg <= 2'b00;
                        jal_reg <= 1'b0;      // 不选择$31！JALR写rd
                        link_reg <= 1'b1;     // 写PC+8
                        jr_reg <= 1'b1;       // 寄存器跳转
                    end
                    default: begin   // 其他R型
                        sigs <= 8'b01100000;
                        aluop_reg <= 2'b10;
                    end
                endcase
            end
            6'b100011:begin     //lw
                sigs <= 8'b01010011;
                aluop_reg <= 2'b00;
            end
            6'b101011:begin     //sw
                sigs <= 8'b00010101;
                aluop_reg <= 2'b00;
            end
            6'b000100:begin     //beq
                sigs <= 8'b00001000;
                aluop_reg <= 2'b01;
            end
            6'b000101:begin     //bne
                sigs <= 8'b00001000;
                aluop_reg <= 2'b01;
            end
            6'b000110:begin     //blez
                sigs <= 8'b00001000;
                aluop_reg <= 2'b01;
            end
            6'b000111:begin     //bgtz
                sigs <= 8'b00001000;
                aluop_reg <= 2'b01;
            end
            6'b000001:begin     //BRANCHS (BLTZ, BGEZ, BLTZAL, BGEZAL)
                case(rt)
                    5'b00000, 5'b00001: begin // BLTZ, BGEZ
                        sigs <= 8'b00001000;
                        aluop_reg <= 2'b01;
                    end
                    5'b10000, 5'b10001: begin // BLTZAL, BGEZAL
                        sigs <= 8'b10001000;
                        aluop_reg <= 2'b01;
                        jal_reg <= 1'b1;
                        link_reg <= 1'b1;
                    end
                    default: begin
                        sigs <= 8'b00000000;
                        aluop_reg <= 2'b00;
                    end
                endcase
            end
            6'b001000:begin     //addi
                sigs <= 8'b01010000;
                aluop_reg <= 2'b00;
            end
            6'b001001:begin     //addiu
                sigs <= 8'b01010000;
                aluop_reg <= 2'b00;
            end
            6'b001101:begin     //ori
                sigs <= 8'b01010000;
                aluop_reg <= 2'b01;  // OR操作
            end
            6'b000010:begin     //j
                sigs <= 8'b10000000;
                aluop_reg <= 2'b00;
            end
            6'b000011:begin     //jal
                sigs <= 8'b11000000;
                aluop_reg <= 2'b00;
                jal_reg <= 1'b1;
                link_reg <= 1'b1;
            end
            default:begin
                sigs <= 8'b00000000;
                aluop_reg <= 2'b00;
            end
        endcase
    end
endmodule
