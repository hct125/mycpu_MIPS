`timescale 1ns / 1ps
`include "defines2.vh"

module mem_ctrl(
    // Write Control (M Stage)
    input wire memwriteM,
    input wire [5:0] opM,
    input wire [1:0] addr_lowM,
    output reg [3:0] ben,

    // Read Control (W Stage)
    input wire [5:0] opW,
    input wire [1:0] addr_lowW,     // alu_resultW[1:0]
    input wire [31:0] mem_rdataW,
    output reg [31:0] final_mem_rdata
);

    // --- Write Control Logic (M Stage) ---
    always @(*) begin
        if (memwriteM) begin 
            case (opM)
                `SB: begin // Store Byte
                    case (addr_lowM)
                        2'b00: ben = 4'b0001;
                        2'b01: ben = 4'b0010;
                        2'b10: ben = 4'b0100;
                        2'b11: ben = 4'b1000;
                    endcase
                end
                `SH: begin // Store Halfword
                    case (addr_lowM[1])
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

    // --- Read Control Logic (W Stage) ---
    always @(*) begin
        case(opW)
            `LB: begin // Signed
                case(addr_lowW)
                    2'b00: final_mem_rdata = {{24{mem_rdataW[7]}},   mem_rdataW[7:0]};
                    2'b01: final_mem_rdata = {{24{mem_rdataW[15]}},  mem_rdataW[15:8]};
                    2'b10: final_mem_rdata = {{24{mem_rdataW[23]}},  mem_rdataW[23:16]};
                    2'b11: final_mem_rdata = {{24{mem_rdataW[31]}},  mem_rdataW[31:24]};
                endcase
            end
            `LBU: begin // Unsigned
                case(addr_lowW)
                    2'b00: final_mem_rdata = {24'b0, mem_rdataW[7:0]};
                    2'b01: final_mem_rdata = {24'b0, mem_rdataW[15:8]};
                    2'b10: final_mem_rdata = {24'b0, mem_rdataW[23:16]};
                    2'b11: final_mem_rdata = {24'b0, mem_rdataW[31:24]};
                endcase
            end
            `LH: begin // Signed
                case(addr_lowW[1])
                    1'b0: final_mem_rdata = {{16{mem_rdataW[15]}}, mem_rdataW[15:0]};
                    1'b1: final_mem_rdata = {{16{mem_rdataW[31]}}, mem_rdataW[31:16]};
                endcase
            end
            `LHU: begin // Unsigned
                case(addr_lowW[1])
                    1'b0: final_mem_rdata = {16'b0, mem_rdataW[15:0]};
                    1'b1: final_mem_rdata = {16'b0, mem_rdataW[31:16]};
                endcase
            end
            default: final_mem_rdata = mem_rdataW; 
        endcase
    end

endmodule
