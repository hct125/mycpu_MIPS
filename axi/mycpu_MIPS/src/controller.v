`timescale 1ns / 1ps
// Controller模块
module controller(
    input clk,rst,
    input wire [31:0] instr,
    // Hazard / Pipeline Interlock Signals
    input wire stallD,      // D阶段暂停 (unused in this module)
    input wire flushD,      // D阶段清空 (unused in this module)
    input wire flushE,      // E阶段清空
    input wire stallE,      // E阶段暂停
    input wire stallW,      // W阶段暂停
    input wire flushM,      // M阶段清空
    input wire flushW,      // W阶段清空
    
    // Output Control Signals
    output wire jump,branch,alusrc,memwrite,memetoreg,regwrite,regdst,data_ram_ena,regwriteE,memtoregM,
    output wire regwriteM,
    output wire memtoregE,
    output wire sext,
    output wire [4:0] alucontrol, // Expanded for Arithmetic
    
    // Link and Jump Signals
    output wire jalD,linkD,jrD,  // D阶段
    output wire jalE,linkE,jrE,  // E阶段
    output wire linkM,           // M阶段
    output wire linkW,           // W阶段
    
    // CP0 / Exception Signals
    output wire cp0weM,
    output wire cp0reE,         // Read in E
    output wire syscallM,
    output wire breakM,
    output wire eretM,
    output wire riM             // Reserved Instruction (无效指令)
);

    //根据instr[31:26]和instr[5:0]解码
    wire [3:0] aluop;       //Main Decode输出的aluop信号，传入ALU Decoder
    wire [8:0] sigsD;       //Main Decode输出的9bit控制信号 {jump,regwrite,regdst,alusrc,branch,memwrite,memetoreg,data_ram_ena,sext}

    //main_dec 实例化
    wire cp0we, cp0re, syscall, break_inst, eret, ri;
    
    main_dec Main_Decoder(
        .op(instr[31:26]),
        .rs(instr[25:21]),      // Added RS for COP0
        .rt(instr[20:16]),      // Required for regimm decode (HEAD)
        .funct(instr[5:0]),     // Required for jr/jalr decode (HEAD)
        .sigs(sigsD),
        .aluop(aluop),
        .jal(jalD),
        .link(linkD),
        .jr(jrD),
        .cp0we(cp0we),
        .cp0re(cp0re),
        .syscall(syscall),
        .break_inst(break_inst),
        .eret(eret),
        .ri(ri)
    );

    wire [4:0] alucontrolD; //ALU Decoder输出的ALU控制信号，传入流水线寄存器

    //alu_dec 实例化
    alu_dec ALU_Control(.funct(instr[5:0]),.op(aluop),.alucontrol(alucontrolD));
    
    // D Stage Outputs
    assign jump = sigsD[8]; //jump和branch信号不用继续传输
    assign branch = sigsD[4];
    assign sext = sigsD[0]; 

    // D->E 流水线寄存器
    // {regwrite, regdst, alusrc, memwrite, memtoreg, data_ram_ena, jal, link, jr, cp0we, cp0re, syscall, break, eret, ri}
    wire memwriteE, data_ram_enaE;
    wire cp0weE, syscallE, breakE, eretE, riE;

    // 控制信号寄存器：stallE保持，flushE清空
    flopenrc #(15) r1E(
        .clk(clk),
        .rst(rst),
        .en(~stallE),
        .clear(flushE),
        .d({sigsD[7], sigsD[6], sigsD[5], sigsD[3], sigsD[2], sigsD[1], jalD, linkD, jrD, cp0we, cp0re, syscall, break_inst, eret, ri}),
        .q({regwriteE, regdst, alusrc, memwriteE, memtoregE, data_ram_enaE, jalE, linkE, jrE, cp0weE, cp0reE, syscallE, breakE, eretE, riE})
    );

    // ALU控制信号寄存器
    flopenrc #(5) r2E(
        .clk(clk),
        .rst(rst),
        .en(~stallE),
        .clear(flushE),
        .d(alucontrolD),
        .q(alucontrol)
    );

    // E->M 流水线寄存器
    // {regwrite, memwrite, memtoreg, data_ram_ena, link, cp0we, syscall, break, eret, ri}
    // 控制信号寄存器：flushM清空（除法暂停时）
    floprc #(10) r1M(
        .clk(clk),
        .rst(rst),
        .clear(flushM),
        .d({regwriteE, memwriteE, memtoregE, data_ram_enaE, linkE, cp0weE, syscallE, breakE, eretE, riE}),
        .q({regwriteM, memwrite, memtoregM, data_ram_ena, linkM, cp0weM, syscallM, breakM, eretM, riM})
    );
    

    // M->W 流水线寄存器
    // {regwrite, memtoreg, link}
    flopenrc #(3) r1W(
        .clk(clk),
        .rst(rst),
        .en(~stallW),
        .clear(flushW),
        .d({regwriteM, memtoregM, linkM}),
        .q({regwrite, memetoreg, linkW})
    );

endmodule
