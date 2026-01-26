`timescale 1ns / 1ps
// MIPS CPU顶层模块

module mips(
    input wire clk,
    input wire rst,
    input wire [31:0] mem_rdata,
    input wire [31:0] instr,
    output wire [31:0] pc,	
    output wire inst_ram_ena,
    output wire data_ram_ena,
    output wire [3:0] data_ram_wea,
    output wire [31:0] alu_result,
    output wire [31:0] mem_wdata,
    // 调试信号
    output wire [31:0] debug_wb_pc,
    output wire [3:0]  debug_wb_rf_wen,
    output wire [4:0]  debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata
);

    wire memtoreg,alusrc,regdst,regwrite,jump,regwriteM,memtoregE,regwriteE,memtoregM,branch;
    wire sext;//符号扩展控制信号
    wire memwrite_1bit;
    wire [4:0] alucontrol;
    wire [31:0] instrD;
    // Link和Jump相关信号
    wire jalD,linkD,jrD,jalE,linkE,jrE,linkM,linkW;
    // stall和flush信号
    wire stallD, flushD, flushE, stallE, flushM, flushW;

    wire cp0weM, cp0reE, syscallM, breakM, eretM, riM;
    
    assign inst_ram_ena = 1'b1; //指令存储器始终使能
	
    // mips = datapath + controller
    controller c(
        .clk(clk),
        .rst(rst),
        .instr(instrD),
        // Hazard信号输入
        .stallD(stallD),
        .flushD(flushD),
        .flushE(flushE),
        .stallE(stallE),
        .flushM(flushM),
        .flushW(flushW),
        // 控制信号输出
        .jump(jump),
        .branch(branch),
        .alusrc(alusrc),
        .memwrite(memwrite_1bit),
        .memetoreg(memtoreg),
        .regwrite(regwrite),
        .regdst(regdst),
        .data_ram_ena(data_ram_ena),
        .regwriteM(regwriteM),
        .memtoregE(memtoregE),
        .regwriteE(regwriteE),
        .memtoregM(memtoregM),
        .sext(sext),
        .alucontrol(alucontrol),
        // Link/Jump 信号输出
        .jalD(jalD),.linkD(linkD),.jrD(jrD),
        .jalE(jalE),.linkE(linkE),.jrE(jrE),
        .linkM(linkM),.linkW(linkW),
        // CP0 signals
        .cp0weM(cp0weM),
        .cp0reE(cp0reE),
        .syscallM(syscallM),
        .breakM(breakM),
        .eretM(eretM),
        .riM(riM)
    );
    
    datapath dp(
        .clk(clk),
        .rst(rst),
        .instr(instr),
        .mem_rdata(mem_rdata),
        .pc(pc),
        .writedataM(mem_wdata),
        .alu_resultM(alu_result),
        // 传入控制信号
        .memtoreg(memtoreg),
        .alusrc(alusrc),
        .regdst(regdst),
        .regwrite(regwrite),
        .jump(jump),
        .branch(branch),
        .memwrite(memwrite_1bit),
        .ben(data_ram_wea),
        .regwriteM(regwriteM),
        .memtoregE(memtoregE),
        .regwriteE(regwriteE),
        .memtoregM(memtoregM),
        .sext(sext),
        .alucontrol(alucontrol),
        // 传入Link/Jump信号
        .jalD(jalD),.linkD(linkD),.jrD(jrD),
        .jalE(jalE),.linkE(linkE),.jrE(jrE),
        .linkM(linkM),.linkW(linkW),
        // CP0 signals
        .cp0weM(cp0weM),
        .cp0reE(cp0reE),
        .syscallM(syscallM),
        .breakM(breakM),
        .eretM(eretM),
        .riM(riM),
        // 传出instrD给controller
        .instrD_to_controller(instrD),
        // 输出Hazard信号
        .stallD(stallD),
        .flushD(flushD),
        .flushE(flushE),
        .stallE(stallE),
        .flushM(flushM),
        .flushW(flushW),
        // 调试信号
        .debug_wb_pc(debug_wb_pc),
        .debug_wb_rf_wen(debug_wb_rf_wen),
        .debug_wb_rf_wnum(debug_wb_rf_wnum),
        .debug_wb_rf_wdata(debug_wb_rf_wdata)
    );
	
endmodule
