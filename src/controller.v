`timescale 1ns / 1ps
module controller(
    input clka,rst,
    input wire [31:0] instr,
    output wire jump,branch,alusrc,memwrite,memetoreg,regwrite,regdst,data_ram_ena,regwriteE,memtoregM,
    output wire regwriteM,  //regwriteE,memtoregM,regwriteM,memtoregE传入datapath中的hazard需要
    output wire memtoregE,
    output wire sext,
    output wire [4:0] alucontrol,
    input wire stallE,
    input wire flushM
    );
    
    //根据instr[31:26]和instr[5:0]解码
    wire [3:0] aluop;       //Main Decode输出的aluop信号，传入ALU Decoder
    wire [8:0] sigsD;       //Main Decode输出的9bit控制信号
    //main_dec 实例化
    main_dec Main_Decoder(.op(instr[31:26]),.sigs(sigsD),.aluop(aluop));
    wire [4:0] alucontrolD; //ALU Decoder输出的ALU控制信号，传入流水线寄存器
    //alu_dec 实例化
    alu_dec ALU_Control(.funct(instr[5:0]),.op(aluop),.alucontrol(alucontrolD));
    assign jump = sigsD[8]; //jump和branch信号不用继续传输，直接传给下一条指令以减少控制冒险
    assign branch = sigsD[4];
    assign sext = sigsD[0];
    
    //流水线寄存器DE间的数据进出：{regwrite,regdst,alusrc,memwrite,memetoreg,data_ram_ena}和ALUControlD
    wire [5:0] sigsE;       //{regwrite,regdst,alusrc,memwrite,memetoreg,data_ram_ena}
    wire [4:0] alucontrolE; //从流水线寄存器DE读出的ALU控制信号
    flopenrc #(6) r1E(.clk(clka),.rst(rst),.en(~stallE),.clear(1'b0),.d({sigsD[7:5],sigsD[3:1]}),.q(sigsE));
    flopenrc #(5) r2E(.clk(clka),.rst(rst),.en(~stallE),.clear(1'b0),.d(alucontrolD),.q(alucontrolE));
    
    assign regdst = sigsE[4];
    assign alusrc = sigsE[3];
    assign alucontrol = alucontrolE;
    assign memtoregE = sigsE[1];
    assign regwriteE = sigsE[5];
    wire [3:0] sigsM;
    floprc #(4) r1M(.clk(clka),.rst(rst),.clear(flushM),.d({sigsE[5],sigsE[2:0]}),.q(sigsM));
    
    assign memwrite = sigsM[2];
    assign data_ram_ena = sigsM[0];
    assign regwriteM = sigsM[3];  //传入datapath中的hazard需要
    assign memtoregM = sigsM[1]; //传入datapath中的hazard需要
    
    //流水线寄存器MW间的数据进出：{regwrite,memetoreg}
    wire [1:0] sigsW;
    floprc #(2) r1W(.clk(clka),.rst(rst),.clear(1'b0),.d({sigsM[3],sigsM[1]}),.q(sigsW));
    assign regwrite = sigsW[1];
    assign memetoreg = sigsW[0];

endmodule