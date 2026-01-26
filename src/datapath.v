`timescale 1ns / 1ps
`include "defines2.vh"
// 数据通路模块
module datapath(
    input wire clk,rst,
    input wire [31:0] instr,
    input wire [31:0] mem_rdata,    // data_ram中读出的数据
    output wire [31:0] pc,
    output wire [31:0] alu_resultM,
    output wire [31:0] writedataM,
    // Control Signals
    input wire memtoreg,		
    input wire alusrc,
    input wire regdst,
    input wire regwrite,
    input wire jump,
    input wire branch,
    input wire memwrite,
    output wire [3:0] ben,
    input wire regwriteM,
    input wire memtoregE,
    input wire regwriteE,
    input wire memtoregM,
    input wire sext,
    input wire [4:0] alucontrol, // Expanded to 5 bits

    // CP0 Signals
    input wire cp0weM,
    input wire cp0reE,
    input wire syscallM,
    input wire breakM,
    input wire eretM,
    input wire riM,
    
    // Link/Jump Signals (HEAD)
    input wire jalD,linkD,jrD,
    input wire jalE,linkE,jrE,
    input wire linkM,linkW,
    
    // Outputs
    output wire [31:0] instrD_to_controller,
    output wire stallD,stallE,
    output wire flushD,flushE,flushM,flushW,
    
    // Debug Signals
    output wire [31:0] debug_wb_pc,
    output wire [3:0]  debug_wb_rf_wen,
    output wire [4:0]  debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata
);
    
    // Exception Wires
    wire flush_exception;
    wire [31:0] pc_exception_target;

    wire [31:0] pc_next;        // pc+4后的下一位pc
    wire [31:0] pc_next_jump;   // 最终PC (Jump/Branch/PC+4)
    wire [31:0] pc_next_final;  // Final PC (Exception handling)
    
    assign pc_next_final = flush_exception ? pc_exception_target : pc_next_jump;

    wire [31:0] rd1D;           // regfile输出的rd1
    wire [31:0] rd2D;           // regfile输出的rd2
    wire [31:0] imm_extend;     // 立即数扩展结果
    wire [31:0] alu_result;     // alu计算结果
    wire [31:0] alu_srcB;       // ALU源B
    wire [31:0] wd3;            // 写regfile数据
    wire [4:0] wa3;             // 写regfile的寄存器号
    wire [31:0] imm_sl2;        // imm_extend左移2位
    wire [31:0] pc_branch;      // branch分支地址
    wire [31:0] pc_plus_4;      // pc+4
    wire [31:0] pc_plus_8E;     // PC+8 (E阶段，用于Link指令)
    wire [31:0] pc_plus_8M;     // PC+8 (M阶段)
    wire [31:0] pc_plus_8W;     // PC+8 (W阶段)
    wire pcsrc;                 // PC分支选择信号
    wire branch_takenD;         // 分支是否发生
    wire jumpD;                 // 最终跳转控制 (来自Control或Check)
    wire jump_conflictD;        // 跳转冲突
    wire [31:0] pcjumpD;        // 跳转目标地址
    wire zero;                  // ALU零标志 (Arithmetic legacy)
    wire [31:0] mux3_A_result;
    wire [31:0] mux3_B_result;
    
    // Hazard Unit Outputs
    wire stallF; // stallE, flushM also generated but outputted
    
    // F-D间信号
    wire [31:0] instrD;
    wire [5:0] opD = instrD[31:26];
    wire [31:0] pc_plus_4D;
    wire [31:0] pcD;
    
    // D-E间信号
    wire [31:0] rd1E;
    wire [31:0] rd2E;
    wire [31:0] pc_plus_4E;
    wire [31:0] imm_extendE;
    wire [5:0] opE;
    wire [4:0] rsE;             // instr[25:21]
    wire [4:0] rtE;             // instr[20:16]
    wire [4:0] rdE;             // instr[15:11]
    wire [4:0] saE;             // instr[10:6]
    wire [4:0] rtD;             // instrD[20:16]
    wire [31:0] pcE;
    assign rtD = instrD[20:16];
    
    // E-M间信号
    wire [31:0] pc_branchM;     
    wire [4:0] wa3M;            
    wire zeroM;
    wire [31:0] pcM;
    
    // M-W间信号
    wire [31:0] alu_resultW;    
    wire [31:0] mem_rdataW;
    wire [31:0] final_mem_rdata;
    wire [5:0] opW;     
    wire [4:0] wa3W;
    wire [31:0] pcW;
    wire memtoregW;  // M->W 阶段的 memtoreg 信号            
    
    // 数据前推控制器
    wire [1:0] forwordAE, forwordBE;
    wire [1:0] forwordAD, forwordBD;  
    wire [31:0] rd1D_forwarded, rd2D_forwarded;
    
    // 实例化 branch_check
    branch_check bc(
        .op(instrD[31:26]),
        .rt(rtD),
        .srca(rd1D_forwarded),
        .srcb(rd2D_forwarded),
        .branch_taken(branch_takenD)
    );
    
    // MIPS Jump Logic
    jump_control jc(
        .instrD(instrD),
        .pcplus4D(pc_plus_4D),
        .srcaD(rd1D_forwarded),
        .regwriteE(regwriteE),
        .regwriteM(regwriteM),
        .writeregE(wa3),         // wa3 (E stage write reg)
        .writeregM(wa3M),
        .jumpD(jumpD),           // Output: Actual jump signal (Control + Condition)
        .jump_conflictD(jump_conflictD), // Output: JR hazard
        .pcjumpD(pcjumpD)        // Output: Jump Target
    );
    
    // PC Source Logic
    assign pcsrc = branch & branch_takenD;

    
    // PC Muxes
    mux2 #(32) mux_pc_next(
        .a(pc_branch),          // Branch Target
        .b(pc_plus_4),          // PC+4
        .s(pcsrc),              
        .y(pc_next)  
    );
    
    mux2 #(32) mux_pc_jump(
        .a(pcjumpD),                 // Jump Target
        .b(pc_next),                 // Branch/PC+4
        .s(jumpD & ~jump_conflictD), // Jump if no conflict
        .y(pc_next_jump)  
    );
    
    // PC Register (StallF)
    pc pc_module(
        .clk(clk),
        .rst(rst),
        .en(~stallF), // stallF is already gated with ~flush_exception in hazard
        .din(pc_next_final),
        .q(pc)
    );
    
    adder pc_plus_4_module(.a(pc),.b(32'h4),.y(pc_plus_4));
    
    // F->D Register (StallD)
    // Clear on flushD (Exception)
    flopenrc #(32) r1D(.clk(clk),.rst(rst),.en(~stallD),.clear(flushD),.d(instr),.q(instrD));
    flopenrc #(32) r2D(.clk(clk),.rst(rst),.en(~stallD),.clear(flushD),.d(pc_plus_4),.q(pc_plus_4D));
    flopenrc #(32) r_pcD(.clk(clk),.rst(rst),.en(~stallD),.clear(flushD),.d(pc),.q(pcD));
    
    assign instrD_to_controller = instrD;
    
    // 符号扩展
    sign_extend ext(
        .a(instrD[15:0]),
        .sext(sext),
        .y(imm_extend)
    );
    
    // Branch Target Calculation
    shift_2 sl2(.a(imm_extend),.y(imm_sl2));
    adder pc_branch_module(.a(pc_plus_4D),.b(imm_sl2),.y(pc_branch));
    
    //寄存器堆
    regfile regfile(
        .clk(clk),
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
    assign resultW = linkW ? pc_plus_8W : (memtoregW ? final_mem_rdata : alu_resultW);
    
    // D阶段转发选择：优先M阶段(2'b10)，其次W阶段(2'b01)
    mux3 #(32) mux_rd1D_forward(.d0(rd1D),.d1(resultW),.d2(realresultM),.s(forwordAD),.y(rd1D_forwarded));
    mux3 #(32) mux_rd2D_forward(.d0(rd2D),.d1(resultW),.d2(realresultM),.s(forwordBD),.y(rd2D_forwarded));
    

    // Branch state pipeline (For Conditional Link fix)
    wire branchE, branch_takenE;
    flopenrc #(1) r_brE(.clk(clk),.rst(rst),.en(~stallE),.clear(flushE),.d(branch),.q(branchE));
    flopenrc #(1) r_btE(.clk(clk),.rst(rst),.en(~stallE),.clear(flushE),.d(branch_takenD),.q(branch_takenE));

    flopenrc #(32) r1E(.clk(clk),.rst(rst),.en(~stallE),.clear(flushE),.d(rd1D),.q(rd1E));
    flopenrc #(32) r2E(.clk(clk),.rst(rst),.en(~stallE),.clear(flushE),.d(rd2D),.q(rd2E));
    flopenrc #(5) r3E(.clk(clk),.rst(rst),.en(~stallE),.clear(flushE),.d(instrD[20:16]),.q(rtE));
    flopenrc #(5) r4E(.clk(clk),.rst(rst),.en(~stallE),.clear(flushE),.d(instrD[15:11]),.q(rdE));
    flopenrc #(32) r5E(.clk(clk),.rst(rst),.en(~stallE),.clear(flushE),.d(pc_plus_4D),.q(pc_plus_4E));
    flopenrc #(32) r6E(.clk(clk),.rst(rst),.en(~stallE),.clear(flushE),.d(imm_extend),.q(imm_extendE));
    flopenrc #(5) r7E(.clk(clk),.rst(rst),.en(~stallE),.clear(flushE),.d(instrD[25:21]),.q(rsE));
    flopenrc #(5) r8E(.clk(clk),.rst(rst),.en(~stallE),.clear(flushE),.d(instrD[10:6]),.q(saE));

    // 访存插入：传递指令其一（D到E） 
    flopenrc #(6) r_opE(.clk(clk),.rst(rst),.en(~stallE),.clear(flushE),.d(opD),.q(opE));
    // 传递PC（D到E）
    flopenrc #(32) r_pcE(.clk(clk),.rst(rst),.en(~stallE),.clear(flushE),.d(pcD),.q(pcE));
    
    //连接regfile的wa3,选择写入结果的地址是rt（lw）还是rd（r-type）还是$31（Link指令）
    wire [4:0] wa3_temp;
    mux2 #(5) mux_wa3_temp(
        .a(rdE),            //rd的地址 (R型 - regdst=1)
        .b(rtE),            //rt的地址 (I型 - regdst=0)
        .s(regdst),         
        .y(wa3_temp)
    );
    wire [4:0] wa3_raw;
    mux2 #(5) mux_wa3(
        .a(5'd31),          //$31 (Link指令 - jalE=1)
        .b(wa3_temp),       
        .s(jalE),           
        .y(wa3_raw)
    );
    // BLTZAL/BGEZAL: 无论分支是否发生，都要写入 $31
    // 只有非 Link 的分支指令在不跳转时才需要取消写入
    // linkE=1 表示是 Link 指令，此时即使分支不发生也要写入
    assign wa3 = (branchE & ~branch_takenE & ~linkE) ? 5'd0 : wa3_raw;
    
    // E阶段转发 wait
    mux3 #(32) srcA_sel3(.d0(rd1E),.d1(resultW),.d2(realresultM),.s(forwordAE),.y(mux3_A_result));
    mux3 #(32) srcB_sel3(.d0(rd2E),.d1(resultW),.d2(realresultM),.s(forwordBE),.y(mux3_B_result));
    
    // alu_srcB
    mux2 #(32) mux_alu_srcb(.a(imm_extendE),.b(mux3_B_result),.s(alusrc),.y(alu_srcB));

    wire overflow_wire;   //暂时未使用的溢出信号
    
    // ALU
    alu alu(
        .a(mux3_A_result),
        .b(alu_srcB),
        .sa(saE),
        .op(alucontrol),
        .result(alu_result),
        .overflow(overflow_wire),
        .zero(zero)
    );

    // 乘法模块
    wire [63:0] mul_result;
    mul u_mul(
        .a(mux3_A_result),
        .b(mux3_B_result),
        .op(alucontrol),
        .result(mul_result)
    );

    // 除法模块
    wire [63:0] div_result;
    wire div_ready;
    wire start_div_req = (alucontrol == `DIV_CONTROL) || (alucontrol == `DIVU_CONTROL);
    wire stall_divE;
    
    // 保存除法操作数和signed标志，防止在除法进行过程中被改变
    reg [31:0] div_opdata1_save;
    reg [31:0] div_opdata2_save;
    reg div_signed_save;
    reg div_start_reg;
    
    always @(posedge clk) begin
        if (rst) begin
            div_opdata1_save <= 32'b0;
            div_opdata2_save <= 32'b0;
            div_signed_save <= 1'b0;
            div_start_reg <= 1'b0;
        end else if (start_div_req && !div_start_reg && !div_ready) begin
            // 除法开始时保存操作数
            div_opdata1_save <= mux3_A_result;
            div_opdata2_save <= mux3_B_result;
            div_signed_save <= (alucontrol == `DIV_CONTROL);
            div_start_reg <= 1'b1;
        end else if (div_ready) begin
            // 除法完成时清除start信号
            div_start_reg <= 1'b0;
        end
    end

    div u_div(
        .clk(clk),
        .rst(rst),
        .signed_div_i(div_signed_save),
        .opdata1_i(div_opdata1_save),
        .opdata2_i(div_opdata2_save),
        .start_i(div_start_reg),
        .annul_i(1'b0),
        .result_o(div_result),
        .ready_o(div_ready)
    );
    
    assign stall_divE = start_div_req & ~div_ready;

    // HI/LO 寄存器逻辑
    wire [31:0] alu_out_hilo;
    hilo_reg u_hilo(
        .clk(clk),
        .rst(rst),
        .start_div(start_div_req),
        .div_ready(div_ready),
        .stallE(stallE),
        .flushE(flushE),              // 新增：E阶段flush信号
        .alucontrol(alucontrol),
        .div_result(div_result),
        .mul_result(mul_result),
        .rs_data(mux3_A_result),
        .alu_result(alu_result),
        .alu_out_final(alu_out_hilo)  // 端口名修正为 alu_out_final
    );

    // CP0 Logic
    wire [31:0] cp0_data_o, cp0_epc_o, cp0_status_o, cp0_cause_o;
    wire timer_int_o;
    wire [31:0] cp0_data_forwarded;
    // Exception Signals (M Stage)
    wire [31:0] excepttypeM;
    wire [31:0] badvaddrM;
    wire is_in_delayslot_M; 

    cp0_reg u_cp0(
        .clk(clk),
        .rst(rst),
        .we_i(cp0weM),
        .waddr_i(wa3M),
        .raddr_i(rdE),
        .data_i(writedataM),
        
        .int_i({timer_int_o, 5'b0}),
        .excepttype_i(excepttypeM),
        .current_inst_addr_i(pcM),
        .is_in_delayslot_i(is_in_delayslot_M),
        .bad_addr_i(badvaddrM),
        
        .data_o(cp0_data_o),
        .count_o(),
        .compare_o(),
        .status_o(cp0_status_o),
        .cause_o(cp0_cause_o),
        .epc_o(cp0_epc_o),
        .config_o(), .prid_o(), .badvaddr(),
        .timer_int_o(timer_int_o)
    );


    assign cp0_data_forwarded = (cp0weM & (wa3M == rdE)) ? writedataM : cp0_data_o;
    
    // Select ALU result or CP0 Read
    wire [31:0] alu_out_final;
    assign alu_out_final = cp0reE ? cp0_data_forwarded : alu_out_hilo;

    // E-M数据传输
    // 使用 flushM 清空流水线寄存器 (插入气泡)
    flopenrc #(32) r1M(.clk(clk),.rst(rst),.en(1'b1),.clear(flushM),.d(alu_out_final),.q(alu_resultM));
    flopenrc #(1) r2M(.clk(clk),.rst(rst),.en(1'b1),.clear(flushM),.d(zero),.q(zeroM));
    
    // 写数据先存入内部寄存器
    wire [31:0] writedataM_raw;
    flopenrc #(32) r3M(.clk(clk),.rst(rst),.en(1'b1),.clear(flushM),.d(mux3_B_result),.q(writedataM_raw));

    // 访存插入：传递指令其二（E到M）
    wire [5:0] opM;
    flopenrc #(6) r_opM(.clk(clk),.rst(rst),.en(1'b1),.clear(flushM),.d(opE),.q(opM));

    // PC+8计算（用于Link指令）
    adder pc_plus_8_module(.a(pc_plus_4E),.b(32'h4),.y(pc_plus_8E));

    flopenrc #(32) r4M(.clk(clk),.rst(rst),.en(1'b1),.clear(flushM),.d(pc_branch),.q(pc_branchM));
    flopenrc #(5) r5M(.clk(clk),.rst(rst),.en(1'b1),.clear(flushM),.d(wa3),.q(wa3M));
    // EM阶段传递PC+8 (HEAD Link Support)
    flopenrc #(32) r6M(.clk(clk),.rst(rst),.en(1'b1),.clear(flushM),.d(pc_plus_8E),.q(pc_plus_8M));
    // 传递PC（E到M）
    flopenrc #(32) r_pcM(.clk(clk),.rst(rst),.en(1'b1),.clear(flushM),.d(pcE),.q(pcM));
    
    // 写数据对齐逻辑：SB需要将字节复制4次，SH需要将半字复制2次
    assign writedataM = (opM == `SW) ? writedataM_raw :
                        (opM == `SH) ? {writedataM_raw[15:0], writedataM_raw[15:0]} :
                        (opM == `SB) ? {writedataM_raw[7:0], writedataM_raw[7:0], writedataM_raw[7:0], writedataM_raw[7:0]} :
                        writedataM_raw;
    
    // 访存添加：写使能生成逻辑
    // 异常时禁用写操作，防止错误地址的写入
    mem_write_ctrl u_mem_write(
        .memwrite(memwrite),
        .opM(opM),
        .addr_low(alu_resultM[1:0]),
        .flush_exception(flush_exception),
        .ben(ben)
    );
    
    // M-W数据传输
    // flushW used to squash M-stage exception instruction
    flopenrc #(32) r1W(.clk(clk),.rst(rst),.en(1'b1),.clear(flushW),.d(alu_resultM),.q(alu_resultW));
    flopenrc #(32) r2W(.clk(clk),.rst(rst),.en(1'b1),.clear(flushW),.d(mem_rdata),.q(mem_rdataW));
    flopenrc #(5) r3W(.clk(clk),.rst(rst),.en(1'b1),.clear(flushW),.d(wa3M),.q(wa3W));
    // MW阶段传递PC+8 (HEAD Link Support)
    flopenrc #(32) r4W(.clk(clk),.rst(rst),.en(1'b1),.clear(flushW),.d(pc_plus_8M),.q(pc_plus_8W));
    // 传递PC（M到W）
    flopenrc #(32) r_pcW(.clk(clk),.rst(rst),.en(1'b1),.clear(flushW),.d(pcM),.q(pcW));
    // 传递memtoreg信号（M到W）- 修复W阶段Load指令结果选择bug
    flopenrc #(1) r_memtoregW(.clk(clk),.rst(rst),.en(1'b1),.clear(flushW),.d(memtoregM),.q(memtoregW));
    
    // 访存插入：传递指令其三（M到W）
    flopenrc #(6) r_opW(.clk(clk),.rst(rst),.en(1'b1),.clear(flushW),.d(opM),.q(opW));
    
    mem_read_ctrl u_mem_read(
        .opW(opW),
        .addr_low(alu_resultW[1:0]),
        .mem_rdataW(mem_rdataW),
        .final_mem_rdata(final_mem_rdata)
    );
    
    assign wd3 = resultW;

    // Exception
    
    wire [5:0] ext_int = {timer_int_o, 5'b0};
    // riM 现在从 controller 传入
    
    // Delay Slot Pipeline
    wire dslotF = (jump | branch | jalD | jrD); 
    wire dslotD, dslotE;
    flopenrc #(1) r_dslD(.clk(clk),.rst(rst),.en(~stallD),.clear(flushE),.d(dslotF),.q(dslotD));
    flopenrc #(1) r_dslE(.clk(clk),.rst(rst),.en(~stallE),.clear(flushE),.d(dslotD),.q(dslotE));
    flopenrc #(1) r_dslM(.clk(clk),.rst(rst),.en(1'b1),.clear(flushM),.d(dslotE),.q(is_in_delayslot_M));
    
    // PC Error
    wire pcErrorF = (pc[1:0] != 2'b00);
    wire pcErrorD, pcErrorE, pcErrorM;
    flopenrc #(1) r_pcErrD(.clk(clk),.rst(rst),.en(~stallD),.clear(flushE),.d(pcErrorF),.q(pcErrorD));
    flopenrc #(1) r_pcErrE(.clk(clk),.rst(rst),.en(~stallE),.clear(flushE),.d(pcErrorD),.q(pcErrorE));
    flopenrc #(1) r_pcErrM(.clk(clk),.rst(rst),.en(1'b1),.clear(flushM),.d(pcErrorE),.q(pcErrorM));

    // Overflow (E->M)
    wire overflowM;
    flopenrc #(1) r_ovM(.clk(clk),.rst(rst),.en(1'b1),.clear(flushM),.d(overflow_wire),.q(overflowM));
    
    // Address Error
    wire [1:0] addr_lowM = alu_resultM[1:0];
    wire addrErrorSwM = (memwrite & ( // Store in M (memwrite is M stage signal here)
                 (opM==`SW && addr_lowM!=2'b00) |
                 (opM==`SH && addr_lowM[0]!=1'b0)
                 ));
    wire addrErrorLwM = (memtoregM & ( // Load in M
                 (opM==`LW && addr_lowM!=2'b00) |
                 (opM==`LH && addr_lowM[0]!=1'b0) |
                 (opM==`LHU && addr_lowM[0]!=1'b0)
                 ));

    // 3. Exception Instantiation
    
    exception exception(
        .rst(rst),
        .ext_int(ext_int),
        .ri(riM),
        .breakM(breakM),
        .syscall(syscallM),
        .overflow(overflowM),
        .addrErrorSw(addrErrorSwM),
        .addrErrorLw(addrErrorLwM),
        .pcError(pcErrorM),
        .eretM(eretM),

        // Connect to CP0 Outputs
        .cp0_status(cp0_status_o),
        .cp0_cause(cp0_cause_o),
        .cp0_epc(cp0_epc_o),

        .pcM(pcM),
        .alu_outM(alu_resultM),

        // Outputs
        .except_type(excepttypeM),
        .flush_exception(flush_exception),
        .pc_exception(pc_exception_target),
        .pc_trap(), // Unused
        .badvaddrM(badvaddrM)
    );
    
    // hazard 实例化
    hazard hazard(
        .rst(rst),
        .rsD(instrD[25:21]),
        .rtD(instrD[20:16]),
        .rsE(rsE),
        .rtE(rtE),
        .regwriteE(regwriteE),.regwriteM(regwriteM),.regwriteW(regwrite),
        .memtoregE(memtoregE),.memtoregM(memtoregM),.branchD(branch),
        .writeregE(wa3),.writeregM(wa3M),.writeregW(wa3W),
        .forwordAE(forwordAE),.forwordBE(forwordBE),.forwordAD(forwordAD),.forwordBD(forwordBD),
        .stallF(stallF),.stallD(stallD),
        .flushD(flushD), // Explicitly connected
        .flushE(flushE),
        // Combined Hazard Logic
        .stall_divE(stall_divE),
        .stallE(stallE),
        .flushM(flushM),
        .flushW(flushW),
        .jump_conflictD(jump_conflictD),
        .linkE(linkE),
        .flush_exception(flush_exception) // Use generated flush_exception
    );
    
    // Debug Signals (Writeback Stage)
    assign debug_wb_pc = pcW;
    assign debug_wb_rf_wen = {4{regwrite}};  // 4位写使能信号
    assign debug_wb_rf_wnum = wa3W;
    assign debug_wb_rf_wdata = resultW;

endmodule
