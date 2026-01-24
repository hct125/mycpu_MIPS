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
    output wire data_ram_wea,
    output wire [31:0] alu_result,
    output wire [31:0] mem_wdata
);

    wire memtoreg,alusrc,regdst,regwrite,jump,regwriteM,memtoregE,regwriteE,memtoregM,branch;
    wire sext;//符号扩展控制信号
    wire [4:0] alucontrol;
    wire [31:0] instrD;
    // Link和Jump相关信号
    wire jalD,linkD,jrD,jalE,linkE,jrE,linkM,linkW;
    // stall和flush信号
    wire stallD, flushE, stallE, flushM;
    
    assign inst_ram_ena = ~rst; // 复位时禁止指令存储器访问
	
    // mips = datapath + controller
    controller c(
        .clk(clk),
        .rst(rst),
        .instr(instrD),
        // Hazard信号输入
        .stallD(stallD),
        .flushE(flushE),
        .stallE(stallE),
        .flushM(flushM),
        // 控制信号输出
        .jump(jump),
        .branch(branch),
        .alusrc(alusrc),
        .memwrite(data_ram_wea),
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
        .linkM(linkM),.linkW(linkW)
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
        // 传出instrD给controller
        .instrD_to_controller(instrD),
        // 输出Hazard信号
        .stallD_out(stallD),
        .flushE_out(flushE),
        .stallE(stallE),
        .flushM(flushM)
    );
	
endmodule
