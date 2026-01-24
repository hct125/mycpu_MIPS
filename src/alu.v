`timescale 1ns / 1ps
// ALU??
module alu(
    input [31:0] a,
    input [31:0] b,
    input [2:0] op,
    output wire [31:0] result,
    output wire zero
);
    assign result = (op == 3'b010) ? a + b :
                    (op == 3'b110) ? a - b :
                    (op == 3'b000) ? a & b :
                    (op == 3'b001) ? a | b :
                    (op == 3'b100) ? ~a : 
                    (op == 3'b111) ? (a < b) : 32'h00000000;
    assign zero = (result == 32'b0);
endmodule
