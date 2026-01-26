`timescale 1ns / 1ps
`include "defines2.vh"

module hilo_reg(
    input wire clk,
    input wire rst,
    input wire start_div,
    input wire div_ready,
    input wire stallE,
    input wire flushE,              // 新增：E阶段flush信号
    input wire [4:0] alucontrol,
    input wire [63:0] div_result,
    input wire [63:0] mul_result,
    input wire [31:0] rs_data,      // mux3_A_result
    input wire [31:0] alu_result,   // Normal ALU result
    output reg [31:0] alu_out_final
);
    reg [31:0] hi, lo;

    always @(posedge clk) begin
        if (rst) begin
            hi <= 0;
            lo <= 0;
        end 
        // 1. 除法写回
        else if (start_div && div_ready) begin
            hi <= div_result[63:32];
            lo <= div_result[31:0];
        end 
        // 2. 只有在流水线不暂停且不flush时 (E阶段有效)，才允许执行 E 阶段的指令写 HI/LO
        else if (~stallE & ~flushE) begin
            case (alucontrol)
                `MULT_CONTROL, `MULTU_CONTROL: begin
                    hi <= mul_result[63:32];
                    lo <= mul_result[31:0];
                end
                `MTHI_CONTROL: begin
                    hi <= rs_data; // rs 的值
                end
                `MTLO_CONTROL: begin
                    lo <= rs_data; // rs 的值
                end
                // 默认保持原值
                default: begin
                    hi <= hi;
                    lo <= lo;
                end
            endcase
        end
    end

    always @(*) begin
        case (alucontrol)
            `MFHI_CONTROL: alu_out_final = hi;
            `MFLO_CONTROL: alu_out_final = lo;
            default:       alu_out_final = alu_result;
        endcase
    end
endmodule
