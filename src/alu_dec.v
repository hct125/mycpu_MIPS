`timescale 1ns / 1ps
// 根据op码和funct码解码，输出对应的alu control信号
module alu_dec(
    input wire [5:0] funct,
    input wire [1:0] op,
    output wire [2:0] alucontrol
);

assign alucontrol = (op == 2'b00) ? 3'b010 : // lw sw addi (ADD)
                    (op == 2'b01) ? 3'b001 : // ori (OR)
                    (op == 2'b10) ? (
                        (funct == 6'b100000) ? 3'b010 : // add
                        (funct == 6'b100010) ? 3'b110 : // sub
                        (funct == 6'b100100) ? 3'b000 : // and
                        (funct == 6'b100101) ? 3'b001 : // or
                        (funct == 6'b101010) ? 3'b111 : // slt 
                        3'b000
                    ) : 3'b000;
                                
endmodule
