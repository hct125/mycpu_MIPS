`timescale 1ns / 1ps
// MIPS CPU顶层模块 - 支持逻辑运算和移位指令

module mips(
    input wire clk,
    input wire rst,
    input wire [31:0] mem_rdata,
    input wire [31:0] instr,	
    output wire [31:0] mem_wdata,
    output wire [31:0] pc,
    output wire inst_ram_ena,
    output wire data_ram_ena,
    output wire data_ram_wea,
    output wire [31:0] alu_result,
    // 兼容旧接口（用于mycpu_top.v）
    output wire memwrite,
    output wire [31:0] aluout,
    output wire [31:0] writedata,
    output wire [31:0] readdata
);
	
    wire memtoreg,alusrc,regdst,regwrite,jump,regwriteM,memtoregE,regwriteE,memtoregM,branch;
    wire[3:0] alucontrol;       // 扩展到4位
    wire [31:0] instrD;
    // 新增：Link和Jump相关信号
    wire jalD,linkD,jrD,jalE,linkE,jrE,linkM,linkW;
    // 新增：stall和flush信号
    wire stallD, flushE;
    // 新增：零扩展选择信号
    wire zero_extD, zero_extE;
    
    assign inst_ram_ena = 1'b1;
	
    // 兼容赋值
    assign memwrite = data_ram_wea;
    assign aluout = alu_result;
    assign writedata = mem_wdata;
    assign readdata = mem_rdata;
	
    // mips = datapath + controller
    controller c(
        .clka(clk),
        .rst(rst),
        .instr(instrD),
        .stallD(stallD),        // 连接stall信号
        .flushE(flushE),        // 连接flush信号
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
        .alucontrol(alucontrol),
        .jalD(jalD),.linkD(linkD),.jrD(jrD),
        .jalE(jalE),.linkE(linkE),.jrE(jrE),
        .linkM(linkM),.linkW(linkW),
        .zero_extD(zero_extD),.zero_extE(zero_extE)
    );
    
    datapath dp(
        .clka(clk),
        .rst(rst),
        .instr(instr),
        .mem_rdata(mem_rdata),
        .pc(pc),
        .writedataM(mem_wdata),
        .alu_resultM(alu_result),
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
        .alucontrol(alucontrol),
        .instrD_to_controller(instrD),
        .jalD(jalD),.linkD(linkD),.jrD(jrD),
        .jalE(jalE),.linkE(linkE),.jrE(jrE),
        .linkM(linkM),.linkW(linkW),
        .zero_extD(zero_extD),.zero_extE(zero_extE),
        // 输出stall和flush信号给controller
        .stallD_out(stallD),
        .flushE_out(flushE)
    );
	
endmodule
