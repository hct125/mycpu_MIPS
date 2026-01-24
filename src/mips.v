`timescale 1ns / 1ps

module mips(
	input wire clk,
    input wire rst,
    input wire [31:0] mem_rdata,
	input wire [31:0] instr,	
	output wire [31:0] mem_wdata,
    output wire [31:0] pc,
    output wire inst_ram_ena,
    output wire data_ram_ena,
    // ===== 访存修改：端口改为 4 位 =====
    output wire [3:0] data_ram_wea,
    // ===== 修改完毕 =====
    output wire [31:0] alu_result    
    );
	
	wire memtoreg,alusrc,regdst,regwrite,jump,regwriteM,memtoregE,regwriteE,memtoregM,branch,sext;
	wire[4:0] alucontrol;
	wire [31:0] instrD;
	wire stallE; 
	wire flushM; 
	
    // ===== 访存修改：定义中间信号 =====
    wire memwrite_1bit; // 用于连接 Controller(1位) 和 Datapath(输入)
    // ===== 修改完毕 =====

	assign inst_ram_ena = ~rst;

	controller c(
        .clka(clk),
        .rst(rst),
        .instr(instrD),
        .jump(jump),
        .branch(branch),
        .alusrc(alusrc),
        // ===== 访存修改：中间量接线 =====
		.memwrite(memwrite_1bit),
        // ===== 修改完毕 =====
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
		.stallE(stallE),
		.flushM(flushM)
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
        .sext(sext),
        .alucontrol(alucontrol),
        .instrD_to_controller(instrD),
		.stallE(stallE),
		.flushM(flushM),
        // ===== 访存修改：中间量接线 =====
        .memwrite(memwrite_1bit), // 输入：来自 Controller
        .ben(data_ram_wea)        // 输出：去往 Data RAM 的 4位写使能
        // ===== 修改完毕 =====
	);
	
endmodule