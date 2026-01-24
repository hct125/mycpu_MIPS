`timescale 1ns / 1ps
/*Main Decoder模块：将jump,regwrite,regdst,alusrc,branch,memwrite,memetoreg,data_ram_ena,sext合并为sigs，方便输入输出
*/
`include "defines2.vh"
module main_dec(
    input wire [5:0] op,
    output reg [8:0]sigs,       //jump,regwrite,regdst,alusrc,branch,memwrite,memetoreg,data_ram_ena,sext
    output wire [3:0] aluop
);
    reg [3:0] aluop_reg;
    assign aluop = aluop_reg;
    always@(*)  begin 
        case(op)
            `R_TYPE:begin     //R
                sigs <= 9'b011000001;
                aluop_reg <= `R_TYPE_OP;
            end
            `LW:begin     //lw
                sigs <= 9'b010100111;
                aluop_reg <= `MEM_OP;
            end
            `SW:begin     //sw
                sigs <= 9'b000101011;
                aluop_reg <= `MEM_OP;
            end
            `BEQ:begin     //beq
                sigs <= 9'b000010001;
                aluop_reg <= `BEQ_OP;
            end
            `ADDI:begin     //addi
                sigs <= 9'b010100001;
                aluop_reg <= `ADDI_OP;
            end
            `ADDIU:begin     //addiu
                sigs <= 9'b010100001;
                aluop_reg <= `ADDIU_OP;
            end
            `ORI:begin      //ori
                sigs <= 9'b010100000;
                aluop_reg <= `ORI_OP;
            end
            `SLTI:begin      //slti
                sigs <= 9'b010100001;
                aluop_reg <= `SLTI_OP;
            end
            `SLTIU:begin      //sltiu
                sigs <= 9'b010100001;
                aluop_reg <= `SLTIU_OP;
            end
            `J:begin    //j
                sigs <= 9'b100000001;
                aluop_reg <= `USELESS_OP;
            end
            default:begin
                sigs <= 9'b000000000;
                aluop_reg <= 4'b0000;
            end
        endcase
    end
endmodule

