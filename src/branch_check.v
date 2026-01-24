`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: branch_check
// Description: 分支条件判断模块 - 支持12条转移指令中的8条分支指令
//////////////////////////////////////////////////////////////////////////////////

module branch_check(
    input wire[5:0] op,
    input wire[4:0] rt,
    input wire[31:0] srca,
    input wire[31:0] srcb,
    output reg branch_taken
);
    always @(*) begin
        case(op)
            6'b000100: // BEQ
                branch_taken = (srca == srcb);
            6'b000101: // BNE
                branch_taken = (srca != srcb);
            6'b000111: // BGTZ
                branch_taken = ($signed(srca) > 0);
            6'b000110: // BLEZ
                branch_taken = ($signed(srca) <= 0);
            6'b000001: begin // BRANCHS (BLTZ, BGEZ, BLTZAL, BGEZAL)
                case(rt)
                    5'b00000, 5'b10000: // BLTZ, BLTZAL
                        branch_taken = ($signed(srca) < 0);
                    5'b00001, 5'b10001: // BGEZ, BGEZAL
                        branch_taken = ($signed(srca) >= 0);
                    default:
                        branch_taken = 1'b0;
                endcase
            end
            default:
                branch_taken = 1'b0;
        endcase
    end
endmodule
