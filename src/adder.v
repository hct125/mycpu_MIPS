`timescale 1ns / 1ps
//32-bit adder
module adder(
	input wire[31:0] a,b,
	output wire[31:0] y
    );
	assign y = a + b;
endmodule

