`timescale 1ns / 1ps
//左移2位模块
module shift_2(
    input wire [31:0] a,
    output wire [31:0] y
    );
    assign y = {a[29:0],2'b00};
endmodule