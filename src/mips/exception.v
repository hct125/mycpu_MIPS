`timescale 1ns / 1ps
`include "defines2.vh"

module exception(
   input rst,
   input [5:0] ext_int,
   input ri, breakM, syscall, overflow, addrErrorSw, addrErrorLw, pcError, eretM,
   input [31:0] cp0_status, cp0_cause, cp0_epc,
   input [31:0] pcM,
   input [31:0] alu_outM,

   output [31:0] except_type,
   output flush_exception,
   output [31:0] pc_exception,
   output pc_trap,
   output [31:0] badvaddrM
);

   //INTERUPT
   // 中断检测逻辑（与参考实现一致）
   // {ext_int[5:0], cause[9:8]} 与 status[15:8] 做与操作
   // status[0] = IE (全局中断使能)
   // status[1] = EXL (异常级别，为1时禁止中断)
   // status[15:8] = IM (中断屏蔽位)
   // cause[9:8] = IP[1:0] (软件中断待处理位)
   wire irp;
   assign irp = (({ext_int, cp0_cause[9:8]} & cp0_status[15:8]) != 8'h00) &&
                (cp0_status[1] == 1'b0) && (cp0_status[0] == 1'b1);

   assign except_type =    (irp)                   ? `EXC_TYPE_INT :
                           (addrErrorLw | pcError) ? `EXC_TYPE_ADEL :
                           (ri)                    ? `EXC_TYPE_RI :
                           (syscall)               ? `EXC_TYPE_SYS :
                           (breakM)                 ? `EXC_TYPE_BP :
                           (addrErrorSw)           ? `EXC_TYPE_ADES :
                           (overflow)              ? `EXC_TYPE_OV :
                           (eretM)                 ? `EXC_TYPE_ERET :
                                                     `EXC_TYPE_NOEXC;
   //interupt pc address
   assign pc_exception =      (except_type == `EXC_TYPE_NOEXC) ? `ZeroWord:
                           (except_type == `EXC_TYPE_ERET)? cp0_epc :
                           32'hbfc0_0380;//异常入口  测试入口0x0000_0040
   assign pc_trap =        (except_type == `EXC_TYPE_NOEXC) ? 1'b0:
                           1'b1;
   assign flush_exception =   (except_type == `EXC_TYPE_NOEXC) ? 1'b0:
                           1'b1;
   assign badvaddrM =      (pcError) ? pcM : alu_outM;

   
endmodule
