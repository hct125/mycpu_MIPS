`timescale 1ns / 1ps
`include "defines2.vh"
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
    input wire sext,
	input wire [4:0] alucontrol,
    output wire [31:0] instrD_to_controller,//从datapath中传出，由于instr必须为D阶段的才能使controller与其匹配。同时instrD受harzard控制，必须从datapath中传出。
    output wire stallE,  //除法器忙信号传出到controller
    output wire flushM,
    // ===== 访存指令新增：引入三位写输入 =====
    input wire memwrite,
    output reg [3:0] ben
    // ===== 增添完毕 =====
    );
    wire [31:0] pc_next;        //pc+4后的下一位pc
    wire [31:0] pc_next_jump;   //选择pc+4?branch后，再次选择是否jump后的PC值
    wire [31:0] rd1D;           //regfile输出的rd1
    wire [31:0] rd2D;           //regfile输出的rd2
    wire [31:0] imm_extend;     //i型指令16位imm有符号扩展成32位
    wire [31:0] alu_result;     //alu计算结果
    wire [31:0] alu_srcB;       //alusec控制得到的alu_srcB
    wire [31:0] wd3;            //写regfile数据(ReadData ? ALUOut)
    wire [4:0] wa3;             //写regfile的寄存器号（rt ? rd）
    wire [31:0] imm_sl2;        //imm_extend左移2位（在branch指令下工作）
    wire [31:0] pc_branch;      //branch分支地址
    wire [31:0] pc_plus_4;      //pc+4
    wire [31:0] instr_jump_offset_sl2; //jump指令中低26位偏移地址左移两位后的结果（这里是32位，高四位后面舍弃）
    wire pcsrc;                 //判断pc 在branch指令下能否执行
    wire zero;                  //提前判断分支，比较branch指令中是否相等
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
    wire forwordAD,forwordBD;
    wire equalD;
    //pcSrc的判断
    assign pcsrc = branch & equalD;
    mux2 #(32) mux_pc_next(
        .a(pc_branch),          //branch的跳转
        .b(pc_plus_4),
        .s(pcsrc),              //连接pcSrc
        .y(pc_next)  
        );
    //j指令的低26位为字地址，左移两位得到字节地址，后面与PC高4位拼接
    shift_2 sl2_pc_jump(
        .a(instrD),
        .y(instr_jump_offset_sl2)  //得到jump指令中偏移地址左移两位后的结果，此处为32位，高4位舍弃
        );
    //j指令的跳转地址
    wire [31:0] jump_addra;
    assign jump_addra = {pc_plus_4[31:28],instr_jump_offset_sl2[27:0]} +4;
    //PC跳转
    mux2 #(32) mux_pc_jump(
        .a(jump_addra), //jump指令下的地址跳转
        .b(pc_next),    //PC+4
        .s(jump),       //jump判断信号
        .y(pc_next_jump)  
        );
    //判断在branch指令时是否要清空pc（流水线延迟导致branch下一条指令执行）
    wire pc_en;
    // stallF 为真，PC 就应该停止自增。
    assign pc_en = ~stallF; 
    //PC
    pc pc_module(.clk(clka),.rst(rst),.en(pc_en),.din(pc_next_jump),.q(pc));
    //PC+4
    adder pc_plus_4_module(.a(pc),.b(32'h4),.y(pc_plus_4));
    //流水线寄存器控制信号
    wire F_D_en;
    assign F_D_en = ~stallD;
    //F-D数据传输
    flopenrc #(32) r1D(.clk(clka),.rst(rst),.en(F_D_en),.clear(1'b0),.d(instr),.q(instrD));
    flopenrc #(32) r2D(.clk(clka),.rst(rst),.en(F_D_en),.clear(1'b0),.d(pc_plus_4),.q(pc_plus_4D));
    
    assign instrD_to_controller = instrD;//从datapath中传出，由于instr必须为D阶段的才能使controller与其匹配。同时instrD受harzard控制，必须从datapath中传出。
    
    //instr低16位偏移地址扩展与左移
    sign_extend sign_extend(.a(instrD[15:0]),.sext(sext),.y(imm_extend));
    shift_2 sl2(.a(imm_extend),.y(imm_sl2));
    //计算branch时PC已经+4了，要还原
    wire [31:0] pc_plus_4D_for_brach;
    assign pc_plus_4D_for_brach = pc_plus_4D - 4;
    adder pc_branch_module(.a(pc_plus_4D_for_brach),.b(imm_sl2),.y(pc_branch));
    //寄存器堆
    regfile regfile(
        .clk(clka),
        .we3(regwrite),                 //写使能 
        .ra1(instrD[25:21]),            //读寄存器号1
        .ra2(instrD[20:16]),            //读寄存器号2
        .wa3(wa3W),                     //写地址
        .wd3(wd3), 	                    //写数据
        .rd1(rd1D),                     //读数据1
        .rd2(rd2D) 	                    //读数据2
        );
    
    wire [31:0] rd1_1sle_branch_A,rd2_1sle_branch_B;
    //rd1_decode_sle_branch_A
    mux2 #(32) mux_rd1_1sle_branch_A(
        .a(alu_result),                 //jump指令下的地址跳转
        .b(rd1D),
        .s(forwordAD),                  //jump
        .y(rd1_1sle_branch_A)  
        );
    //rd2_decode_sle_branch_B
    mux2 #(32) mux_rd2_1sle_branch_B(.a(alu_result),.b(rd2D),.s(forwordBD),.y(rd2_1sle_branch_B));
    //提前判断分支减少控制冒险
    assign equalD = (rd1_1sle_branch_A == rd2_1sle_branch_B);
    //判断branch时是否要清空excute级流水线
    wire D_E_en;  
    assign D_E_en = flushE & pcsrc;
    
    wire [4:0] saE;
    //D-E数据传输
    // We need to use stallE to stop updating pipeline registers when DIV is busy
    wire E_en = ~stallE;
    
    flopenrc #(32) r1E(.clk(clka),.rst(rst),.en(E_en),.clear(D_E_en),.d(rd1D),.q(rd1E));
    flopenrc #(32) r2E(.clk(clka),.rst(rst),.en(E_en),.clear(D_E_en),.d(rd2D),.q(rd2E));
    flopenrc #(5) r3E(.clk(clka),.rst(rst),.en(E_en),.clear(D_E_en),.d(instrD[20:16]),.q(rtE));
    flopenrc #(5) r4E(.clk(clka),.rst(rst),.en(E_en),.clear(D_E_en),.d(instrD[15:11]),.q(rdE));
    flopenrc #(32) r5E(.clk(clka),.rst(rst),.en(E_en),.clear(D_E_en),.d(pc_plus_4D),.q(pc_plus_4E));
    flopenrc #(32) r6E(.clk(clka),.rst(rst),.en(E_en),.clear(D_E_en),.d(imm_extend),.q(imm_extendE));
    flopenrc #(5) r7E(.clk(clka),.rst(rst),.en(E_en),.clear(D_E_en),.d(instrD[25:21]),.q(rsE));
    flopenrc #(5) r8E(.clk(clka),.rst(rst),.en(E_en),.clear(D_E_en),.d(instrD[10:6]),.q(saE));
    
    // ===== 访存插入：传递指令其一（D到E） =====
    wire [5:0] opD = instrD[31:26]; 
    wire [5:0] opE;
    flopenrc #(6) r_opE(.clk(clka),.rst(rst),.en(E_en),.clear(D_E_en),.d(opD),.q(opE));
    // ===== 插入完毕 =====
    
    //连接regfile的wa3,选择写入结果的地址是rt（lw）还是rd（r-type）
    mux2 #(5) mux_wa3(.a(rdE),.b(rtE),.s(regdst),.y(wa3));
    
    mux3 #(32) srcA_sel3(.d0(rd1E),.d1(wd3),.d2(alu_resultM),.s(forwordAE),.y(mux3_A_result));
    
    mux3 #(32) srcB_sel3(.d0(rd2E),.d1(wd3),.d2(alu_resultM),.s(forwordBE),.y(mux3_B_result));
    
    //alu_srcB
    mux2 #(32) mux_alu_srcb(.a(imm_extendE),.b(mux3_B_result),.s(alusrc),.y(alu_srcB));

    wire overflow_wire;  //溢出标志,暂时未使用
    
    //ALU
    alu alu(
        .a(mux3_A_result),
        .b(alu_srcB),
        .sa(saE),
        .op(alucontrol),
        .result(alu_result),
        .overflow(overflow_wire),
        .zero(zero)
    );

    // MUL Module (Multiplication)
    wire [63:0] mul_result;
    
    mul u_mul(
        .a(mux3_A_result),
        .b(mux3_B_result),
        .op(alucontrol),
        .result(mul_result)
    );

    //除法模块
    wire [63:0] div_result;
    wire div_ready;
    wire start_div = (alucontrol == `DIV_CONTROL) || (alucontrol == `DIVU_CONTROL);
    wire signed_div = (alucontrol == `DIV_CONTROL);

    // 实例化 div 模块
    div u_div(
        .clk(clka),
        .rst(rst),
        .signed_div_i(signed_div),
        .opdata1_i(mux3_A_result),
        .opdata2_i(mux3_B_result),
        .start_i(start_div),
        .annul_i(1'b0),
        .result_o(div_result),
        .ready_o(div_ready)
    );
    
    // 如果 div 收到开始信号，且尚未准备好 (ready 为低)，则暂停流水线
    assign stall_divE = start_div & ~div_ready;

    // HI/LO 寄存器
    reg [31:0] hi, lo;
    
    // ===== 修改HI/LO写入逻辑 =====
    always @(posedge clka) begin
        if (rst) begin
            hi <= 0;
            lo <= 0;
        end 
        // 1. 除法写回
        // 加上 start_div 是为了防止 div_ready 的 X 态干扰
        else if (start_div && div_ready) begin
            hi <= div_result[63:32];
            lo <= div_result[31:0];
        end 
        // 2. 只有在流水线不暂停时 (E阶段有效)，才允许执行 E 阶段的指令写 HI/LO
        else if (~stallE) begin
            case (alucontrol)
                `MULT_CONTROL, `MULTU_CONTROL: begin
                    hi <= mul_result[63:32];
                    lo <= mul_result[31:0];
                end
                `MTHI_CONTROL: begin
                    hi <= mux3_A_result; // rs 的值
                end
                `MTLO_CONTROL: begin
                    lo <= mux3_A_result; // rs 的值
                end
                // --- 默认保持原值 ---
                default: begin
                    hi <= hi;
                    lo <= lo;
                end
            endcase
        end
    end
    reg [31:0] alu_out_final; 
    always @(*) begin
        case (alucontrol)
            `MFHI_CONTROL: alu_out_final = hi;
            `MFLO_CONTROL: alu_out_final = lo;
            default:       alu_out_final = alu_result;
        endcase
    end
    //E-M数据传输
    flopenrc #(32) r1M(.clk(clka),.rst(rst),.en(1'b1),.clear(flushM),.d(alu_out_final),.q(alu_resultM));
    // ===== 修改完毕 =====
    
    flopenrc #(1) r2M(.clk(clka),.rst(rst),.en(1'b1),.clear(flushM),.d(zero),.q(zeroM));
    flopenrc #(32) r3M(.clk(clka),.rst(rst),.en(1'b1),.clear(flushM),.d(mux3_B_result),.q(writedataM));
    flopenrc #(32) r4M(.clk(clka),.rst(rst),.en(1'b1),.clear(flushM),.d(pc_branch),.q(pc_branchM)); 
    flopenrc #(5) r5M(.clk(clka),.rst(rst),.en(1'b1),.clear(flushM),.d(wa3),.q(wa3M));

    // ===== 访存插入：传递指令其二（E到M） =====
    wire [5:0] opM;
    flopenrc #(6) r_opM(.clk(clka),.rst(rst),.en(1'b1),.clear(flushM),.d(opE),.q(opM));
    // ===== 插入完毕 =====
    
    // ===== 访存添加：写使能生成逻辑 =====
    always @(*) begin
        if (memwrite) begin // 使用新加进来的输入信号 memwrite
            case (opM)
                `SB: begin // Store Byte
                    case (alu_resultM[1:0])
                        2'b00: ben = 4'b0001;
                        2'b01: ben = 4'b0010;
                        2'b10: ben = 4'b0100;
                        2'b11: ben = 4'b1000;
                    endcase
                end
                `SH: begin // Store Halfword
                    case (alu_resultM[1])
                        1'b0: ben = 4'b0011;
                        1'b1: ben = 4'b1100;
                    endcase
                end
                default: ben = 4'b1111; // SW 指令
            endcase
        end else begin
            ben = 4'b0000; // 如果 controller 说不写，那就全为 0
        end
    end
    // ===== 添加完毕 =====
    
    //M-W数据传输
    flopenrc #(32) r1W(.clk(clka),.rst(rst),.en(1'b1),.clear(1'b0),.d(alu_resultM),.q(alu_resultW));
    flopenrc #(32) r2W(.clk(clka),.rst(rst),.en(1'b1),.clear(1'b0),.d(mem_rdata),.q(mem_rdataW));
    flopenrc #(5) r3W(.clk(clka),.rst(rst),.en(1'b1),.clear(1'b0),.d(wa3M),.q(wa3W));
    
    // ===== 访存插入：传递指令其三（M到W）
    wire [5:0] opW;
    flopenrc #(6) r_opW(.clk(clka),.rst(rst),.en(1'b1),.clear(1'b0),.d(opM),.q(opW));
    // ===== 插入完毕 =====
    //wd3
    
    // ===== 访存修改：删除原实例化 =====
    // 原实例化：mux2 #(32) mux_wd3(.a(mem_rdataW),.b(alu_resultW),.s(memtoreg),.y(wd3));
    reg [31:0] final_mem_rdata;                 // 处理后的内存数据
    wire [1:0] byte_offset = alu_resultW[1:0];  // 地址低两位，决定取哪个字节
    always @(*) begin
        case(opW)
            // --- 字节加载 ---
            `LB: begin // Signed
                case(byte_offset)
                    2'b00: final_mem_rdata = {{24{mem_rdataW[7]}},   mem_rdataW[7:0]};
                    2'b01: final_mem_rdata = {{24{mem_rdataW[15]}},  mem_rdataW[15:8]};
                    2'b10: final_mem_rdata = {{24{mem_rdataW[23]}},  mem_rdataW[23:16]};
                    2'b11: final_mem_rdata = {{24{mem_rdataW[31]}},  mem_rdataW[31:24]};
                endcase
            end
            `LBU: begin // Unsigned
                case(byte_offset)
                    2'b00: final_mem_rdata = {24'b0, mem_rdataW[7:0]};
                    2'b01: final_mem_rdata = {24'b0, mem_rdataW[15:8]};
                    2'b10: final_mem_rdata = {24'b0, mem_rdataW[23:16]};
                    2'b11: final_mem_rdata = {24'b0, mem_rdataW[31:24]};
                endcase
            end
            // --- 半字加载 ---
            `LH: begin // Signed
                case(byte_offset[1])
                    1'b0: final_mem_rdata = {{16{mem_rdataW[15]}}, mem_rdataW[15:0]};
                    1'b1: final_mem_rdata = {{16{mem_rdataW[31]}}, mem_rdataW[31:16]};
                endcase
            end
            `LHU: begin // Unsigned
                case(byte_offset[1])
                    1'b0: final_mem_rdata = {16'b0, mem_rdataW[15:0]};
                    1'b1: final_mem_rdata = {16'b0, mem_rdataW[31:16]};
                endcase
            end
            // --- 默认情况 (LW) ---
            default: final_mem_rdata = mem_rdataW; 
        endcase
    end
    mux2 #(32) mux_wd3(.a(final_mem_rdata),.b(alu_resultW),.s(memtoreg),.y(wd3));
    // ===== 修改完毕 =====
    
    hazard hazard(.rst(rst),.rsD(instrD[25:21]),.rtD(instrD[20:16]),.rsE(rsE),.rtE(rtE),
        .regwriteE(regwriteE),.regwriteM(regwriteM),.regwriteW(regwrite),.memtoregE(memtoregE), 
        .memtoregM(memtoregM),.branchD(branch),.writeregE(wa3),.writeregM(wa3M),.writeregW(wa3W),
        .forwordAE(forwordAE),.forwordBE(forwordBE),.forwordAD(forwordAD),.forwordBD(forwordBD),
        .stallF(stallF),.stallD(stallD),.flushE(flushE),.stall_divE(stall_divE),.stallE(stallE),.flushM(flushM));

endmodule

