`timescale 1ns / 1ps
// PC?? - ????
// ? en=0 ???PC????????

module pc #(parameter WIDTH = 32)(
    input wire clk,rst,en,
    input wire [WIDTH-1:0] din,
    output reg [WIDTH-1:0] q
);
    always @(posedge clk, posedge rst) begin
        if(rst) begin
            q <= 0;
        end else if(en) begin
            q <= din;
        end
        // ? en=0 ???? q ???????
    end
endmodule
