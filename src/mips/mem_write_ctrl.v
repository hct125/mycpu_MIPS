`timescale 1ns / 1ps
`include "defines2.vh"

module mem_write_ctrl(
    input wire memwrite,
    input wire [5:0] opM,
    input wire [1:0] addr_low, // alu_resultM[1:0]
    input wire flush_exception, // 异常时禁用写操作
    output reg [3:0] ben
);
    always @(*) begin
        if (memwrite & ~flush_exception) begin 
            case (opM)
                `SB: begin // Store Byte
                    case (addr_low)
                        2'b00: ben = 4'b0001;
                        2'b01: ben = 4'b0010;
                        2'b10: ben = 4'b0100;
                        2'b11: ben = 4'b1000;
                    endcase
                end
                `SH: begin // Store Halfword
                    case (addr_low[1])
                        1'b0: ben = 4'b0011;
                        1'b1: ben = 4'b1100;
                    endcase
                end
                default: ben = 4'b1111; // SW 指令
            endcase
        end else begin
            ben = 4'b0000; 
        end
    end
endmodule
