`timescale 1ns / 1ps
// Controller模块 - 支持12条转移指令
// 控制信号通过流水线传递，正确处理 flushE 和 stallD

module controller(
    input clka,rst,
    input wire [31:0] instr,
    input wire stallD,      // D阶段暂停
    input wire flushE,      // E阶段清空
    output wire jump,branch,alusrc,memwrite,memetoreg,regwrite,regdst,data_ram_ena,regwriteE,memtoregM,
    output wire regwriteM,
    output wire memtoregE,
    output wire [2:0] alucontrol,
    // 新增：Link和Jump相关信号
    output wire jalD,linkD,jrD,  // D阶段
    output wire jalE,linkE,jrE,  // E阶段
    output wire linkM,           // M阶段
    output wire linkW            // W阶段
);

    // D阶段信号
    wire [1:0] aluop;
    wire [7:0] sigsD;
    wire jalD_temp, linkD_temp, jrD_temp;
    wire [2:0] alucontrolD;
    
    // main_dec 实例化
    main_dec Main_Decoder(
        .op(instr[31:26]),
        .rt(instr[20:16]),
        .funct(instr[5:0]),
        .sigs(sigsD),
        .aluop(aluop),
        .jal(jalD_temp),
        .link(linkD_temp),
        .jr(jrD_temp)
    );
    
    assign jalD = jalD_temp;
    assign linkD = linkD_temp;
    assign jrD = jrD_temp;
    
    // alu_dec 实例化
    alu_dec ALU_Control(.funct(instr[5:0]),.op(aluop),.alucontrol(alucontrolD));
    
    // D阶段直接输出
    assign jump = sigsD[7];
    assign branch = sigsD[3];

    // ==================== D->E 流水线寄存器（行为级，支持flush和stall）====================
    // sigsD: {jump[7], regwrite[6], regdst[5], alusrc[4], branch[3], memwrite[2], memtoreg[1], data_ram_ena[0]}
    reg regwriteE_r, regdstE_r, alusrcE_r, memwriteE_r, memtoregE_r, data_ram_enaE_r;
    reg [2:0] alucontrolE_r;
    reg jalE_r, linkE_r, jrE_r;
    
    always @(posedge clka) begin
        if (rst | flushE) begin
            // 复位或flush时清零
            regwriteE_r <= 0;
            regdstE_r <= 0;
            alusrcE_r <= 0;
            memwriteE_r <= 0;
            memtoregE_r <= 0;
            data_ram_enaE_r <= 0;
            alucontrolE_r <= 0;
            jalE_r <= 0;
            linkE_r <= 0;
            jrE_r <= 0;
        end else if (~stallD) begin
            // 没有stall时更新
            regwriteE_r <= sigsD[6];
            regdstE_r <= sigsD[5];
            alusrcE_r <= sigsD[4];
            memwriteE_r <= sigsD[2];
            memtoregE_r <= sigsD[1];
            data_ram_enaE_r <= sigsD[0];
            alucontrolE_r <= alucontrolD;
            jalE_r <= jalD;
            linkE_r <= linkD;
            jrE_r <= jrD;
        end
        // stall时保持不变
    end
    
    assign regwriteE = regwriteE_r;
    assign regdst = regdstE_r;
    assign alusrc = alusrcE_r;
    assign memtoregE = memtoregE_r;
    assign alucontrol = alucontrolE_r;
    assign jalE = jalE_r;
    assign linkE = linkE_r;
    assign jrE = jrE_r;
    
    // E阶段内部信号
    wire memwriteE_internal = memwriteE_r;
    wire data_ram_enaE_internal = data_ram_enaE_r;

    // ==================== E->M 流水线寄存器 ====================
    reg regwriteM_r, memwriteM_r, memtoregM_r, data_ram_enaM_r, linkM_r;
    
    always @(posedge clka) begin
        if (rst) begin
            regwriteM_r <= 0;
            memwriteM_r <= 0;
            memtoregM_r <= 0;
            data_ram_enaM_r <= 0;
            linkM_r <= 0;
        end else begin
            regwriteM_r <= regwriteE_r;
            memwriteM_r <= memwriteE_r;
            memtoregM_r <= memtoregE_r;
            data_ram_enaM_r <= data_ram_enaE_r;
            linkM_r <= linkE_r;
        end
    end
    
    assign regwriteM = regwriteM_r;
    assign memwrite = memwriteM_r;
    assign memtoregM = memtoregM_r;
    assign data_ram_ena = data_ram_enaM_r;
    assign linkM = linkM_r;

    // ==================== M->W 流水线寄存器 ====================
    reg regwriteW_r, memtoregW_r, linkW_r;
    
    always @(posedge clka) begin
        if (rst) begin
            regwriteW_r <= 0;
            memtoregW_r <= 0;
            linkW_r <= 0;
        end else begin
            regwriteW_r <= regwriteM_r;
            memtoregW_r <= memtoregM_r;
            linkW_r <= linkM_r;
        end
    end
    
    assign regwrite = regwriteW_r;
    assign memetoreg = memtoregW_r;
    assign linkW = linkW_r;

endmodule
