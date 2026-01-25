`timescale 1ns / 1ps
// flip-flop with enable, rst, clear
// clear ?? en=1 ???

module flopenrc #(parameter WIDTH = 8)(
    input wire clk,rst,en,clear,
    input wire[WIDTH-1:0] d,
    output reg[WIDTH-1:0] q
);
    always @(posedge clk) begin
        if(rst) begin
            q <= 0;
        end else if(en) begin
            if(clear) begin
                q <= 0;
            end else begin
                q <= d;
            end
        end
        // ??en=0???????
    end
endmodule
