`timescale 1ns / 1ps
/*Controller模块：解码部分原理同实验二，此处输出控制信号时不能直接输出8bit sigs，而是单独输出。
    本模块不仅负责解码，还需要操控每一级流水线和流水线寄存器之间的数据进出。下为各信号输出位置：
    jump、branch：Main Decoder后
    alucontrol、alusrc、regdst、regwriteE、memtoregE：流水线寄存器DE后
    memwrite、data_ram_ena、memtoregM、regwriteM：流水寄存器EM后
    regwrite、memtoreg：流水寄存器MW后
    其中regwriteE,memtoregM,regwriteM,memtoregE均为传入datapath中的hazard模块，处理冒险情况
*/
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
    
    // 关键修正：Ex级流水线寄存器应当受 stallE (这里用 stall_divE代替, 需确保逻辑一致) 控制
    // 如果除法器忙，ID->EX 的控制信号也不应更新，应保持当前指令的控制信号
    // 然而 controller 内部的 floprc 没有 en 端口，这可能是问题的根源。
    // 我们需要将其替换为 flopenrc，并传入 ~stall_divE 作为使能信号。
    // 但是这里使用的是 floprc (without enable)，这会导致每一拍控制信号都往下流。
    
    // 临时方案：如果 floprc 没有 en，我们需要在这里清零或者保持？
    // 通常 Hazard 单元会清除 ID/EX 寄存器 (FlushE)。但如果是 Stall，应该保持。
    // 让我们查看 floprc 的定义。如果不能暂停，下一条指令的控制信号就会覆盖当前正在做除法的指令信号。
    
    // 正确的做法：将 r1E, r2E 换成 flopenrc，并使用 ~stallE 控制
    // 当前 controller 接收了 stallE。

    flopenrc #(6) r1E(.clk(clka),.rst(rst),.en(~stallE),.clear(1'b0),.d({sigsD[7:5],sigsD[3:1]}),.q(sigsE));
    flopenrc #(5) r2E(.clk(clka),.rst(rst),.en(~stallE),.clear(1'b0),.d(alucontrolD),.q(alucontrolE));
    
    assign regdst = sigsE[4];
    assign alusrc = sigsE[3];
    assign alucontrol = alucontrolE;
    assign memtoregE = sigsE[1];
    assign regwriteE = sigsE[5];
    
    //流水线寄存器EM间的数据进出：{regwrite,memwrite,memetoreg,data_ram_ena}
    wire [3:0] sigsM;
    // 同样，EM 级寄存器也应该受控，或者被 flush。
    // 在 datapath 中，我们已经令 stall_divE 产生 flushM。
    // 如果 controller 中的控制信号流向 M 级，也应该被 flush 或 stall。
    // 根据 datapath 的逻辑，Ex 级被暂停，意味着Ex级的输出无效。
    // 因此 M 级应该接收气泡 (Control signals zeroed out)。
    // 这里使用 flush (clear) 逻辑。我们用 stall_divE 作为 clear 信号。
    
    // 注意：原来的 r1M 是 floprc。我们需要把它变成 flopenrc 并且支持 clear。
    // floprc 的 clear 端口已经有了。
    // 当 stall_divE 为 1 时，意味着 EX 级还没算完，所以不能让 EX 级的有效控制信号流向 M 级。
    // 应该向 M 级插入气泡（即清零 M 级控制信号）。
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