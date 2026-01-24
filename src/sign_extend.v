`timescale 1ns / 1ps
//????????16????????32?
module sign_extend(
    input wire [15:0] a,
    input wire sext,
    output wire [31:0] y
    );
assign y = sext ? {{16{a[15]}},a} : {16'b0, a};

endmodule
