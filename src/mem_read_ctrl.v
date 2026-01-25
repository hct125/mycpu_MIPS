`timescale 1ns / 1ps
`include "defines2.vh"

module mem_read_ctrl(
    input wire [5:0] opW,
    input wire [1:0] addr_low, // alu_resultW[1:0]
    input wire [31:0] mem_rdataW,
    output reg [31:0] final_mem_rdata
);
    always @(*) begin
        case(opW)
            `LB: begin // Signed
                case(addr_low)
                    2'b00: final_mem_rdata = {{24{mem_rdataW[7]}},   mem_rdataW[7:0]};
                    2'b01: final_mem_rdata = {{24{mem_rdataW[15]}},  mem_rdataW[15:8]};
                    2'b10: final_mem_rdata = {{24{mem_rdataW[23]}},  mem_rdataW[23:16]};
                    2'b11: final_mem_rdata = {{24{mem_rdataW[31]}},  mem_rdataW[31:24]};
                endcase
            end
            `LBU: begin // Unsigned
                case(addr_low)
                    2'b00: final_mem_rdata = {24'b0, mem_rdataW[7:0]};
                    2'b01: final_mem_rdata = {24'b0, mem_rdataW[15:8]};
                    2'b10: final_mem_rdata = {24'b0, mem_rdataW[23:16]};
                    2'b11: final_mem_rdata = {24'b0, mem_rdataW[31:24]};
                endcase
            end
            `LH: begin // Signed
                case(addr_low[1])
                    1'b0: final_mem_rdata = {{16{mem_rdataW[15]}}, mem_rdataW[15:0]};
                    1'b1: final_mem_rdata = {{16{mem_rdataW[31]}}, mem_rdataW[31:16]};
                endcase
            end
            `LHU: begin // Unsigned
                case(addr_low[1])
                    1'b0: final_mem_rdata = {16'b0, mem_rdataW[15:0]};
                    1'b1: final_mem_rdata = {16'b0, mem_rdataW[31:16]};
                endcase
            end
            default: final_mem_rdata = mem_rdataW; 
        endcase
    end
endmodule
