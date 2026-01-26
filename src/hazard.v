`timescale 1ns / 1ps
// Hazard Unit - 解决数据冒险与控制冒险
module hazard(
    input wire rst,
    input wire [4:0] rsD,       // D阶段rs
    input wire [4:0] rtD,       // D阶段rt
    input wire [4:0] rsE,       // E阶段rs
    input wire [4:0] rtE,       // E阶段rt
    input wire regwriteE,       // E阶段写寄存器使能
    input wire regwriteM,       // M阶段写寄存器使能
    input wire regwriteW,       // W阶段写寄存器使能
    input wire memtoregE,       // E阶段是否从内存读取 (Load指令)
    input wire memtoregM,       // M阶段是否从内存读取 (Load指令)
    input wire branchD,         // D阶段是否为分支指令
    input wire [4:0] writeregE, // E阶段目标寄存器
    input wire [4:0] writeregM, // M阶段目标寄存器
    input wire [4:0] writeregW, // W阶段目标寄存器
    input wire stall_divE,      // E阶段除法器忙信号 (Arithmetic新增)
    input wire jump_conflictD,  // 跳转冲突（JR/JALR的rs有数据冒险）(HEAD新增)
    input wire linkE,           // E阶段是否为Link指令 (HEAD新增)
    input wire flush_exception, // 异常/ERET清空流水线 (Exception新增)
    
    // Outputs
    output [1:0] forwordAE,     // E阶段SrcA转发控制
    output [1:0] forwordBE,     // E阶段SrcB转发控制
    output [1:0] forwordAD,     // D阶段rs转发控制 (分支判断用)
    output [1:0] forwordBD,     // D阶段rt转发控制 (分支判断用)
    output reg stallF,          // F阶段暂停
    output reg stallD,          // D阶段暂停
    output reg stallE,          // E阶段暂停
    output reg flushD,          // D阶段清空 (新增: 用于异常)
    output reg flushE,          // E阶段清空 (插入气泡)
    output reg flushM,          // M阶段清空 (插入气泡)
    output reg flushW           // W阶段清空 (新增: 用于异常，清除M级指令的写回/访存)
);

    // E阶段转发逻辑 (Data Hazard on ALU)
    // 处理 ALU 指令的数据依赖
    // 10: 数据来自 M 阶段 (上一条指令的 ALU 结果，优先级高)
    // 01: 数据来自 W 阶段 (上上条指令的写回数据)
    // 00: 无转发，使用寄存器堆读取值
    
    assign forwordAE = ((rsE != 5'b0) & (rsE == writeregM) & regwriteM) ? 2'b10 : 
                       ((rsE != 5'b0) & (rsE == writeregW) & regwriteW) ? 2'b01 : 
                        2'b00;
                        
    assign forwordBE = ((rtE != 5'b0) & (rtE == writeregM) & regwriteM) ? 2'b10 :
                       ((rtE != 5'b0) & (rtE == writeregW) & regwriteW) ? 2'b01 :
                        2'b00;

    // D阶段转发逻辑 (Control Hazard on Branch)
    // 处理分支指令在 ID 阶段的数据依赖
    // 10: 数据来自 M 阶段 (上一条指令结果)
    // 01: 数据来自 W 阶段 (上上条指令结果)
    
    assign forwordAD = ((rsD != 5'b0) & (rsD == writeregM) & regwriteM) ? 2'b10 : 
                       ((rsD != 5'b0) & (rsD == writeregW) & regwriteW) ? 2'b01 : 
                       2'b00;
                       
    assign forwordBD = ((rtD != 5'b0) & (rtD == writeregM) & regwriteM) ? 2'b10 : 
                       ((rtD != 5'b0) & (rtD == writeregW) & regwriteW) ? 2'b01 : 
                       2'b00;

    // 流水线暂停 (Stall) 逻辑 
    wire lwstall, branch_stall, jump_stall, link_stall;
    
    // 1. Load-Use 冒险
    // Load 指令在 E 阶段，且 D 阶段指令需要用到该 Load 的结果作为源操作数
    assign lwstall = memtoregE & ((rsD == rtE) | (rtD == rtE)) & (rtE != 0);
    
    // 2. 分支冒险
    // 分支指令在 D 阶段，由于需要立即判断条件，如果操作数还没准备好，必须阻塞
    // 情况A: 前一条指令还在 E 阶段运算 (regwriteE)，结果未产出 -> Stall
    // 情况B: 前一条指令是 Load 且在 M 阶段 (memtoregM)，结果未读出 -> Stall (必须等它到 W 阶段)
    assign branch_stall = branchD & (
        (regwriteE & ((writeregE == rsD) | (writeregE == rtD)) & (writeregE != 0)) |
        (memtoregM & ((writeregM == rsD) | (writeregM == rtD)) & (writeregM != 0))
    );
    
    // 3. 跳转冒险
    // JR/JALR 指令需要读取 rs 寄存器，如果存在数据冒险则阻塞
    assign jump_stall = jump_conflictD;
    
    // 4. Link 冒险
    // 前一条指令是 Link 指令 (如 BGEZAL) 在 E 阶段，当前指令需要读取 $31
    assign link_stall = linkE & regwriteE & (
        ((writeregE == rsD) & (rsD != 0)) | 
        ((writeregE == rtD) & (rtD != 0))
    );
    
    // 最终暂停/清空信号生成 
    // stall_divE (除法器忙) 具有最高优先级，会导致流水线停顿
    // flush_exception (异常) 具有更高优先级，必须刷新所有阶段
    
    always @(*) begin
        // F/D 阶段暂停：存在任何冒险或除法器忙
        // 如果发生异常，强制不暂停(让PC更新)
        stallF = rst ? 1'b0 : (~flush_exception & (lwstall | branch_stall | jump_stall | link_stall | stall_divE));
        stallD = rst ? 1'b0 : (~flush_exception & (lwstall | branch_stall | jump_stall | link_stall | stall_divE));
        
        // E 阶段暂停：仅在除法运算时暂停，保持 ALU 状态
        stallE = rst ? 1'b0 : (~flush_exception & stall_divE); 
        
        // 此处flush信号逻辑：
        // flushD: 异常发生时，清除F-D寄存器
        flushD = rst ? 1'b0 : flush_exception;
        
        // flushE (D-E寄存器): Load冒险 / 分支冒险 / 异常
        flushE = rst ? 1'b0 : (lwstall | branch_stall | jump_stall | link_stall | flush_exception); 
        
        // flushM (E-M寄存器): 除法 / 异常
        flushM = rst ? 1'b0 : (stall_divE | flush_exception); 

        // flushW (M-W寄存器): 异常
        flushW = rst ? 1'b0 : flush_exception;
    end

endmodule