`timescale 1ns / 1ps
// MIPS CPU顶层模块
// AXI版本 - 支持i_stall/d_stall暂停信号

module mips(
    input wire clk,
    input wire rst,
    // 指令SRAM接口
    output wire inst_sram_en,
    output wire [31:0] inst_sram_addr,
    input wire [31:0] inst_sram_rdata,
    input wire i_stall,                 // 取指暂停（来自 i_sram_to_sram_like）
    // 数据SRAM接口
    output wire data_sram_en,
    output wire [31:0] data_sram_addr,
    input wire [31:0] data_sram_rdata,
    output wire [3:0] data_sram_wen,
    output wire [31:0] data_sram_wdata,
    input wire d_stall,                 // 数据访问暂停（来自 d_sram_to_sram_like）
    // 暂停信号输出（用于 SRAM-like 转换）
    output wire longest_stall,          // i_stall | d_stall | stall_divE
    output wire other_stall,            // 除 i_stall/d_stall 外的其他暂停
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
    wire stallD, flushD, flushE, stallE, stallM, stallW, flushM, flushW;

    wire cp0weM, cp0reE, syscallM, breakM, eretM, riM;
    
    // AXI接口信号映射
    wire [31:0] pc;
    wire [31:0] alu_result;
    wire [31:0] mem_wdata;
    wire [3:0] data_ram_wea;
    wire data_ram_ena;
    
    // 异常信号 - 用于禁止取指
    wire flush_exception;
    
    // PC非对齐检测
    wire pc_misaligned = (pc[1:0] != 2'b00);
    
    // 当有异常或PC非对齐时禁止取指
    // 1. flush_exception: 异常发生时停止取指
    // 2. pc_misaligned: PC非对齐时停止取指（避免发送无效AXI请求导致stall）
    assign inst_sram_en = ~flush_exception & ~pc_misaligned;
    assign inst_sram_addr = pc;
    assign data_sram_en = data_ram_ena;
    assign data_sram_addr = alu_result;
    assign data_sram_wen = data_ram_wea;
    assign data_sram_wdata = mem_wdata;
	
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
        .stallM(stallM),
        .stallW(stallW),
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
        .instr(inst_sram_rdata),
        .mem_rdata(data_sram_rdata),
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
        // AXI暂停信号输入
        .i_stall(i_stall),
        .d_stall(d_stall),
        // 输出Hazard信号
        .stallD(stallD),
        .flushD(flushD),
        .flushE(flushE),
        .stallE(stallE),
        .stallM(stallM),
        .stallW(stallW),
        .flushM(flushM),
        .flushW(flushW),
        // AXI暂停信号输出
        .longest_stall(longest_stall),
        .other_stall(other_stall),
        // 异常信号输出
        .flush_exception(flush_exception),
        // 调试信号
        .debug_wb_pc(debug_wb_pc),
        .debug_wb_rf_wen(debug_wb_rf_wen),
        .debug_wb_rf_wnum(debug_wb_rf_wnum),
        .debug_wb_rf_wdata(debug_wb_rf_wdata)
    );
	
endmodule
