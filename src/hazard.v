`timescale 1ns / 1ps
// 冒险检测模块：支持数据转发+流水线阻塞
// 支持12条转移指令的冒险处理

module hazard(
    input wire rst,
    input wire [4:0] rsD,       // D阶段rs
    input wire [4:0] rtD,       // D阶段rt
    input wire [4:0] rsE,       // E阶段rs
    input wire [4:0] rtE,       // E阶段rt
    input wire regwriteE,       // E阶段写寄存器使能
    input wire regwriteM,       // M阶段写寄存器使能
    input wire regwriteW,       // W阶段写寄存器使能
    input wire memtoregE,       // E阶段是否从内存读取
    input wire memtoregM,       // M阶段是否从内存读取
    input wire branchD,         // D阶段是否为分支指令
    input wire [4:0] writeregE, // E阶段目标寄存器
    input wire [4:0] writeregM, // M阶段目标寄存器
    input wire [4:0] writeregW, // W阶段目标寄存器
    output [1:0] forwordAE,     // E阶段SrcA转发控制
    output [1:0] forwordBE,     // E阶段SrcB转发控制
    output [1:0] forwordAD,     // D阶段rs转发控制
    output [1:0] forwordBD,     // D阶段rt转发控制
    output wire stallF,         // F阶段暂停
    output wire stallD,         // D阶段暂停
    output wire flushE,         // E阶段清空
    input wire jump_conflictD,  // 跳转冲突（JR/JALR的rs有数据冒险）
    input wire linkE            // E阶段是否为Link指令
);

    // ==================== E阶段转发逻辑 ====================
    // 01 -> M阶段转发, 10 -> W阶段转发
    assign forwordAE = ((rsE != 5'b0) & (rsE == writeregM) & regwriteM) ? 2'b01 :  // M阶段转发
                       ((rsE != 5'b0) & (rsE == writeregW) & regwriteW) ? 2'b10 :  // W阶段转发
                        2'b00;
    assign forwordBE = ((rtE != 5'b0) & (rtE == writeregM) & regwriteM) ? 2'b01 :
                       ((rtE != 5'b0) & (rtE == writeregW) & regwriteW) ? 2'b10 :
                        2'b00;

    // ==================== D阶段转发逻辑 ====================
    // 用于分支判断和跳转地址计算
    // 10 -> M阶段转发, 01 -> W阶段转发
    assign forwordAD = ((rsD != 5'b0) & (rsD == writeregM) & regwriteM) ? 2'b10 :  // M阶段转发
                       ((rsD != 5'b0) & (rsD == writeregW) & regwriteW) ? 2'b01 :  // W阶段转发
                       2'b00;
    assign forwordBD = ((rtD != 5'b0) & (rtD == writeregM) & regwriteM) ? 2'b10 :
                       ((rtD != 5'b0) & (rtD == writeregW) & regwriteW) ? 2'b01 :
                       2'b00;

    // ==================== Stall逻辑 ====================
    wire lwstall, branch_stall, jump_stall, link_stall;
    
    // LW stall：load指令后紧跟使用该数据的指令
    assign lwstall = memtoregE & ((rsD == rtE) | (rtD == rtE)) & (rtE != 0);
    
    // 分支stall：分支指令需要的数据还在E阶段或M阶段的load指令中
    assign branch_stall = branchD & (
        (regwriteE & ((writeregE == rsD) | (writeregE == rtD))) |
        (memtoregM & ((writeregM == rsD) | (writeregM == rtD)))
    );
    
    // 跳转stall：JR/JALR的rs在E阶段写回时需要stall
    assign jump_stall = jump_conflictD;
    
    // Link stall：当E阶段是Link指令且D阶段指令需要读取Link的目标寄存器时阻塞
    assign link_stall = linkE & regwriteE & (
        ((writeregE == rsD) & (rsD != 0)) | 
        ((writeregE == rtD) & (rtD != 0))
    );
    
    assign stallF = lwstall | branch_stall | jump_stall | link_stall;
    assign stallD = lwstall | branch_stall | jump_stall | link_stall;
    assign flushE = lwstall | branch_stall | jump_stall | link_stall;

endmodule
