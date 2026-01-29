`timescale 1ns / 1ps
// Hazard Unit - 解决数据冒险与控制冒险
// AXI版本 - i_stall 和 d_stall 由外部模块提供
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
    input wire stall_divE,      // E阶段除法器忙信号
    input wire i_stall,         // 取指暂停（来自 i_sram_to_sram_like）
    input wire d_stall,         // 数据访问暂停（来自 d_sram_to_sram_like）
    input wire jump_conflictD,  // 跳转冲突
    input wire linkE,           // E阶段是否为Link指令
    input wire flush_exception, // 异常/ERET清空流水线
    
    // Outputs
    output [1:0] forwordAE,     // E阶段SrcA转发控制
    output [1:0] forwordBE,     // E阶段SrcB转发控制
    output [1:0] forwordAD,     // D阶段rs转发控制
    output [1:0] forwordBD,     // D阶段rt转发控制
    output wire stallF,         // F阶段暂停
    output wire flushF,         // F阶段清空（异常时flush PC）
    output wire stallD,         // D阶段暂停
    output wire stallE,         // E阶段暂停
    output wire stallM,         // M阶段暂停
    output wire stallW,         // W阶段暂停
    output wire flushD,         // D阶段清空
    output wire flushE,         // E阶段清空
    output wire flushM,         // M阶段清空
    output wire flushW,         // W阶段清空
    output wire longest_stall,  // i_stall | d_stall | stall_divE
    output wire other_stall     // 除 i_stall/d_stall 外的其他暂停条件
);

    // E阶段转发逻辑
    assign forwordAE = ((rsE != 5'b0) & (rsE == writeregM) & regwriteM) ? 2'b10 : 
                       ((rsE != 5'b0) & (rsE == writeregW) & regwriteW) ? 2'b01 : 
                        2'b00;
                        
    assign forwordBE = ((rtE != 5'b0) & (rtE == writeregM) & regwriteM) ? 2'b10 :
                       ((rtE != 5'b0) & (rtE == writeregW) & regwriteW) ? 2'b01 :
                        2'b00;

    // D阶段转发逻辑
    assign forwordAD = ((rsD != 5'b0) & (rsD == writeregM) & regwriteM) ? 2'b10 : 
                       ((rsD != 5'b0) & (rsD == writeregW) & regwriteW) ? 2'b01 : 
                       2'b00;
                       
    assign forwordBD = ((rtD != 5'b0) & (rtD == writeregM) & regwriteM) ? 2'b10 : 
                       ((rtD != 5'b0) & (rtD == writeregW) & regwriteW) ? 2'b01 : 
                       2'b00;

    // 流水线冒险检测
    wire lwstall, branch_stall, jump_stall, link_stall;
    
    // 1. Load-Use 冒险
    assign lwstall = memtoregE & ((rsD == rtE) | (rtD == rtE)) & (rtE != 0);
    
    // 2. 分支冒险
    assign branch_stall = branchD & (
        (regwriteE & ((writeregE == rsD) | (writeregE == rtD)) & (writeregE != 0)) |
        (memtoregM & ((writeregM == rsD) | (writeregM == rtD)) & (writeregM != 0))
    );
    
    // 3. 跳转冒险
    assign jump_stall = jump_conflictD;
    
    // 4. Link 冒险
    assign link_stall = linkE & regwriteE & (
        ((writeregE == rsD) & (rsD != 0)) | 
        ((writeregE == rtD) & (rtD != 0))
    );
    
    // other_stall: 除 i_stall/d_stall 外的所有暂停条件
    assign other_stall = lwstall | branch_stall | jump_stall | link_stall | stall_divE;
    
    // longest_stall: i_stall | d_stall | stall_divE
    // 保护：如果 stall_divE 是 x，则当作 0 处理
    wire stall_divE_safe = (stall_divE === 1'bx) ? 1'b0 : stall_divE;
    assign longest_stall = i_stall | d_stall | stall_divE_safe;
    
    // 保护：如果 flush_exception 是 x，则当作 0 处理（不 flush）
    wire flush_exception_safe = (flush_exception === 1'bx) ? 1'b0 : flush_exception;
    
    // 暂停/清空信号（严格参考 2024CQU-CO-LAB hazard.v）
    // stallD = lwstallD | branchstallD | longest_stall
    assign stallD = lwstall | branch_stall | jump_stall | link_stall | longest_stall;
    
    // stallF = stallD & ~flushexceptM
    assign stallF = stallD & ~flush_exception_safe;
    
    // stallE = stallM = longest_stall
    assign stallE = longest_stall;
    assign stallM = longest_stall;
    
    // stallW = longest_stall & ~flushexceptM
    assign stallW = longest_stall & ~flush_exception_safe;
    
    // flushF = flushD = flushexceptM (与参考实现一致)
    assign flushF = flush_exception_safe;
    assign flushD = flush_exception_safe;
    
    // flushE = 当 D 阶段暂停但 E 阶段不暂停时，需要向 E 阶段插入气泡
    assign flushE = ((lwstall | branch_stall | jump_stall | link_stall) & ~longest_stall) | flush_exception_safe;
    
    // flushM = flushW = flushexceptM
    assign flushM = flush_exception_safe;
    assign flushW = flush_exception_safe;

endmodule
