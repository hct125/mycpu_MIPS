`timescale 1ns / 1ps
// mycpu_top - SoC
module top(
    input wire clk,
    input wire resetn,
    input wire [5:0] ext_int,
    
    // 指令SRAM接口
    output wire inst_sram_en,
    output wire [3:0] inst_sram_wen,
    output wire [31:0] inst_sram_addr, inst_sram_wdata,
    input wire [31:0] inst_sram_rdata,
    // 数据SRAM接口
    output wire data_sram_en,
    output wire [3:0] data_sram_wen,
    output wire [31:0] data_sram_addr, data_sram_wdata,
    input wire [31:0] data_sram_rdata,
    // 调试信号
    output wire [31:0] debug_wb_pc,
    output wire [3:0] debug_wb_rf_wen,
    output wire [4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata
);

    wire [31:0] pc;
    wire [31:0] data_addr;
    
    // SRAM
    assign inst_sram_en = 1'b1;
    assign inst_sram_wen = 4'b0;
    assign inst_sram_wdata = 32'b0;
    
    // MMU
    wire [31:0] inst_paddr;
    wire [31:0] data_paddr;
    wire no_dcache;
    
    mmu mmu_inst(
        .inst_vaddr(pc),
        .inst_paddr(inst_paddr),
        .data_vaddr(data_addr),
        .data_paddr(data_paddr),
        .no_dcache(no_dcache)
    );
    
    assign inst_sram_addr = inst_paddr;
    assign data_sram_addr = data_paddr;
    
    // CPU  Block RAM 
    wire inst_ram_ena_internal;
    mips mips(
        .clk(~clk),                 // 
        .rst(~resetn),              // resetn高电平有效
        .instr(inst_sram_rdata),
        .mem_rdata(data_sram_rdata),

        .pc(pc),
        .inst_ram_ena(inst_ram_ena_internal),
        .data_ram_ena(data_sram_en),
        .data_ram_wea(data_sram_wen),
        .alu_result(data_addr),
        .mem_wdata(data_sram_wdata),
        // debug
        .debug_wb_pc(debug_wb_pc),
        .debug_wb_rf_wen(debug_wb_rf_wen),
        .debug_wb_rf_wnum(debug_wb_rf_wnum),
        .debug_wb_rf_wdata(debug_wb_rf_wdata)
    );

endmodule