`timescale 1ns / 1ps
// 数据通路模块 - 支持12条转移指令

module datapath(
    input wire clka,rst,
    input wire [31:0] instr,
    input wire [31:0] mem_rdata,    //data_ram中读出的数据
    output wire [31:0] pc,
    output wire [31:0] alu_resultM,
    output wire [31:0] writedataM,
    input wire memtoreg,		
    input wire alusrc,
    input wire regdst,
    input wire regwrite,
    input wire jump,
    input wire branch,
    input wire regwriteM,
    input wire memtoregE,
    input wire regwriteE,
    input wire memtoregM,
    input wire [2:0] alucontrol,
    output wire [31:0] instrD_to_controller,
    // 新增：Link和Jump相关信号
    input wire jalD,linkD,jrD,
    input wire jalE,linkE,jrE,
    input wire linkM,linkW,
    // 输出stall和flush信号给controller
    output wire stallD_out,
    output wire flushE_out
    );
    
    wire [31:0] pc_next;        //pc+4后的下一位pc
    wire [31:0] pc_next_jump;   //选择pc+4/branch后，再次选择是否jump后的PC值
    wire [31:0] rd1D;           //regfile输出的rd1
    wire [31:0] rd2D;           //regfile输出的rd2
    wire [31:0] imm_extend;     //i型指令16位imm有符号扩展成32位
    wire [31:0] alu_result;     //alu计算结果
    wire [31:0] alu_srcB;       //alusec控制得到的alu_srcB
    wire [31:0] wd3;            //写regfile数据(ReadData / ALUOut / PC+8)
    wire [4:0] wa3;             //写regfile的寄存器号（rt / rd / $31）
    wire [31:0] imm_sl2;        //imm_extend左移2位（在branch指令下工作）
    wire [31:0] pc_branch;      //branch分支地址
    wire [31:0] pc_plus_4;      //pc+4
    wire [31:0] pc_plus_8E;     //PC+8 (E阶段，用于Link指令)
    wire [31:0] pc_plus_8M;     //PC+8 (M阶段)
    wire [31:0] pc_plus_8W;     //PC+8 (W阶段)
    wire pcsrc;                 //判断pc 在branch指令下能否执行
    wire branch_takenD;         //分支条件判断结果
    wire jumpD;                 //跳转信号（来自jump_control）
    wire jump_conflictD;        //跳转冲突（JR/JALR的rs有数据冒险）
    wire [31:0] pcjumpD;        //跳转目标地址（来自jump_control）
    wire zero;                  //ALU零标志
    wire [31:0] mux3_A_result;
    wire [31:0] mux3_B_result;
    
    //F-D间信号
    wire [31:0] instrD;
    wire [31:0] pc_plus_4D;
    
    //D-E间信号
    wire [31:0] rd1E;
    wire [31:0] rd2E;
    wire [31:0] pc_plus_4E;
    wire [31:0] imm_extendE;
    wire [4:0] rsE;             //instr[25:21]，用于hazard模块
    wire [4:0] rtE;             //filereg回写地址时 rt的地址 传入mux wa3
    wire [4:0] rdE;             //filereg回写地址时 rd的地址 传入mux wa3
    wire [4:0] rtD;             //用于branch_check
    assign rtD = instrD[20:16];
    
    //E-M间信号
    wire [31:0] pc_branchM;     //branch指令下pc跳转结果
    wire [4:0] wa3M;            //选择rd还是rs写回数据的结果
    
    //M-W间信号
    wire [31:0] alu_resultW;    //回写的aluresult，送到选择器去
    wire [31:0] mem_rdataW;     //Data_ram中读出，送到writeback阶段的选择器
    wire [4:0] wa3W;            //选择rd还是rs写回数据的结果
    wire zeroM;
    
    //hazard传出的延迟与刷新信号
    wire stallF,stallD,flushE;
    
    //数据前推控制器
    wire [1:0] forwordAE,forwordBE;
    wire [1:0] forwordAD,forwordBD;  // 改为2位，支持M和W阶段转发
    wire [31:0] rd1D_forwarded, rd2D_forwarded;  // D阶段转发后的寄存器值
    
    // 分支条件判断模块
    branch_check bc(
        .op(instrD[31:26]),
        .rt(rtD),
        .srca(rd1D_forwarded),
        .srcb(rd2D_forwarded),
        .branch_taken(branch_takenD)
    );
    
    // 跳转控制模块
    jump_control jc(
        .instrD(instrD),
        .pcplus4D(pc_plus_4D),
        .srcaD(rd1D_forwarded),
        .regwriteE(regwriteE),
        .regwriteM(regwriteM),
        .writeregE(wa3),
        .writeregM(wa3M),
        .jumpD(jumpD),
        .jump_conflictD(jump_conflictD),
        .pcjumpD(pcjumpD)
    );
    
    //pcSrc的判断 (使用branch_takenD)
    assign pcsrc = branch & branch_takenD;
    mux2 #(32) mux_pc_next(
        .a(pc_branch),          //branch的跳转
        .b(pc_plus_4),
        .s(pcsrc),              //连接pcSrc
        .y(pc_next)  
    );
    
    //PC跳转 (使用jump_control的输出)
    mux2 #(32) mux_pc_jump(
        .a(pcjumpD),    //跳转目标地址（来自jump_control）
        .b(pc_next),    //PC+4或branch地址
        .s(jumpD & ~jump_conflictD),  //无冲突时才跳转
        .y(pc_next_jump)  
    );
    
    //PC
    pc pc_module(.clk(clka),.rst(rst),.en(~stallF),.din(pc_next_jump),.q(pc));
    
    //PC+4
    adder pc_plus_4_module(.a(pc),.b(32'h4),.y(pc_plus_4));
    
    //F-D数据传输
    flopenrc #(32) r1D(.clk(clka),.rst(rst),.en(~stallD),.clear(1'b0),.d(instr),.q(instrD));
    flopenrc #(32) r2D(.clk(clka),.rst(rst),.en(~stallD),.clear(1'b0),.d(pc_plus_4),.q(pc_plus_4D));
    
    assign instrD_to_controller = instrD;
    

    
    //计算branch目标地址
    adder pc_branch_module(.a(pc_plus_4D),.b(imm_sl2),.y(pc_branch));
    
    //寄存器堆
    regfile regfile(
        .clk(clka),
        .we3(regwrite),                 //写使能 
        .ra1(instrD[25:21]),            //读寄存器号1
        .ra2(instrD[20:16]),            //读寄存器号2
        .wa3(wa3W),                     //写地址
        .wd3(wd3),                      //写数据
        .rd1(rd1D),                     //读数据1
        .rd2(rd2D)                      //读数据2
    );
    
    // M阶段最终结果（用于转发）：Link指令优先返回PC+8
    wire [31:0] realresultM;
    assign realresultM = linkM ? pc_plus_8M : (memtoregM ? mem_rdata : alu_resultM);
    
    // W阶段最终结果（用于转发）：Link指令优先返回PC+8
    wire [31:0] resultW;
    assign resultW = linkW ? pc_plus_8W : (memtoreg ? mem_rdataW : alu_resultW);
    
    // D阶段转发选择：优先M阶段(2'b10)，其次W阶段(2'b01)
    mux3 #(32) mux_rd1D_forward(.d0(rd1D),.d1(resultW),.d2(realresultM),.s(forwordAD),.y(rd1D_forwarded));
    mux3 #(32) mux_rd2D_forward(.d0(rd2D),.d1(resultW),.d2(realresultM),.s(forwordBD),.y(rd2D_forwarded));
    
    //D-E数据传输
    flopenrc #(32) r1E(.clk(clka),.rst(rst),.en(~stallD),.clear(flushE),.d(rd1D),.q(rd1E));
    flopenrc #(32) r2E(.clk(clka),.rst(rst),.en(~stallD),.clear(flushE),.d(rd2D),.q(rd2E));
    flopenrc #(5) r3E(.clk(clka),.rst(rst),.en(~stallD),.clear(flushE),.d(instrD[20:16]),.q(rtE));
    flopenrc #(5) r4E(.clk(clka),.rst(rst),.en(~stallD),.clear(flushE),.d(instrD[15:11]),.q(rdE));
    flopenrc #(32) r5E(.clk(clka),.rst(rst),.en(~stallD),.clear(flushE),.d(pc_plus_4D),.q(pc_plus_4E));
    flopenrc #(32) r6E(.clk(clka),.rst(rst),.en(~stallD),.clear(flushE),.d(imm_extend),.q(imm_extendE));
    flopenrc #(5) r7E(.clk(clka),.rst(rst),.en(~stallD),.clear(flushE),.d(instrD[25:21]),.q(rsE));
    
    // PC+8计算（用于Link指令）
    assign pc_plus_8E = pc_plus_4E + 32'd4;
    
    //连接regfile的wa3,选择写入结果的地址是rt（lw）还是rd（r-type）还是$31（Link指令）
    // mux2是 y = s ? a : b，所以 s=1选a，s=0选b
    wire [4:0] wa3_temp;
    mux2 #(5) mux_wa3_temp(
        .a(rdE),            //rd的地址 (R型指令) - regdst=1时选择
        .b(rtE),            //rt的地址 (I型指令) - regdst=0时选择
        .s(regdst),         
        .y(wa3_temp)
    );
    mux2 #(5) mux_wa3(
        .a(5'd31),          //$31 (Link指令) - jalE=1时选择
        .b(wa3_temp),       //rt或rd - jalE=0时选择
        .s(jalE),           //jalE信号选择$31
        .y(wa3)
    );
    
    // E阶段转发：使用realresultM和resultW
    mux3 #(32) srcA_sel3(.d0(rd1E),.d1(realresultM),.d2(resultW),.s(forwordAE),.y(mux3_A_result));
    mux3 #(32) srcB_sel3(.d0(rd2E),.d1(realresultM),.d2(resultW),.s(forwordBE),.y(mux3_B_result));
    
    //alu_srcB
    mux2 #(32) mux_alu_srcb(.a(imm_extendE),.b(mux3_B_result),.s(alusrc),.y(alu_srcB));
    
    //ALU
    alu alu(.a(mux3_A_result),.b(alu_srcB),.op(alucontrol),.result(alu_result),.zero(zero));

    //E-M数据传输
    flopenrc #(32) r1M(.clk(clka),.rst(rst),.en(1'b1),.clear(1'b0),.d(alu_result),.q(alu_resultM));
    flopenrc #(1) r2M(.clk(clka),.rst(rst),.en(1'b1),.clear(1'b0),.d(zero),.q(zeroM));
    flopenrc #(32) r3M(.clk(clka),.rst(rst),.en(1'b1),.clear(1'b0),.d(mux3_B_result),.q(writedataM));
    flopenrc #(32) r4M(.clk(clka),.rst(rst),.en(1'b1),.clear(1'b0),.d(pc_branch),.q(pc_branchM));
    flopenrc #(5) r5M(.clk(clka),.rst(rst),.en(1'b1),.clear(1'b0),.d(wa3),.q(wa3M));
    // EM阶段传递PC+8
    flopenrc #(32) r6M(.clk(clka),.rst(rst),.en(1'b1),.clear(1'b0),.d(pc_plus_8E),.q(pc_plus_8M));
    
    //M-W数据传输
    flopenrc #(32) r1W(.clk(clka),.rst(rst),.en(1'b1),.clear(1'b0),.d(alu_resultM),.q(alu_resultW));
    flopenrc #(32) r2W(.clk(clka),.rst(rst),.en(1'b1),.clear(1'b0),.d(mem_rdata),.q(mem_rdataW));
    flopenrc #(5) r3W(.clk(clka),.rst(rst),.en(1'b1),.clear(1'b0),.d(wa3M),.q(wa3W));
    // MW阶段传递PC+8
    flopenrc #(32) r4W(.clk(clka),.rst(rst),.en(1'b1),.clear(1'b0),.d(pc_plus_8M),.q(pc_plus_8W));
    
    //wd3: 使用resultW（已包含Link的PC+8选择）
    assign wd3 = resultW;
    
    hazard hazard(.rst(rst),.rsD(instrD[25:21]),.rtD(instrD[20:16]),.rsE(rsE),.rtE(rtE),
        .regwriteE(regwriteE),.regwriteM(regwriteM),.regwriteW(regwrite),.memtoregE(memtoregE), 
        .memtoregM(memtoregM),.branchD(branch),.writeregE(wa3),.writeregM(wa3M),.writeregW(wa3W),
        .forwordAE(forwordAE),.forwordBE(forwordBE),.forwordAD(forwordAD),.forwordBD(forwordBD),
        .stallF(stallF),.stallD(stallD),.flushE(flushE),
        .jump_conflictD(jump_conflictD),
        .linkE(linkE));
    
    // 输出stall和flush信号给controller
    assign stallD_out = stallD;
    assign flushE_out = flushE;

endmodule
