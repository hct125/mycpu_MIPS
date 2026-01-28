`timescale 1ns / 1ps
// top - AXI版本顶层模块
// 架构：mips(SRAM) -> i_sram_to_sram_like/d_sram_to_sram_like -> cpu_axi_interface -> AXI
// 模块名为 top，以匹配 soc_axi_lite_top.v 中的实例化
module top(
    input wire aclk,
    input wire aresetn,
    input wire [5:0] ext_int,

    // AXI
    // ar - 读地址通道
    output wire [3 :0] arid,
    output wire [31:0] araddr,
    output wire [7 :0] arlen,
    output wire [2 :0] arsize,
    output wire [1 :0] arburst,
    output wire [1 :0] arlock,
    output wire [3 :0] arcache,
    output wire [2 :0] arprot,
    output wire        arvalid,
    input  wire        arready,
    // r - 读数据通道
    input  wire [3 :0] rid,
    input  wire [31:0] rdata,
    input  wire [1 :0] rresp,
    input  wire        rlast,
    input  wire        rvalid,
    output wire        rready,
    // aw - 写地址通道
    output wire [3 :0] awid,
    output wire [31:0] awaddr,
    output wire [7 :0] awlen,
    output wire [2 :0] awsize,
    output wire [1 :0] awburst,
    output wire [1 :0] awlock,
    output wire [3 :0] awcache,
    output wire [2 :0] awprot,
    output wire        awvalid,
    input  wire        awready,
    // w - 写数据通道
    output wire [3 :0] wid,
    output wire [31:0] wdata,
    output wire [3 :0] wstrb,
    output wire        wlast,
    output wire        wvalid,
    input  wire        wready,
    // b - 写响应通道
    input  wire [3 :0] bid,
    input  wire [1 :0] bresp,
    input  wire        bvalid,
    output wire        bready,

    // 调试信号
    output wire [31:0] debug_wb_pc,
    output wire [3:0] debug_wb_rf_wen,
    output wire [4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata
);

    wire clk = aclk;
    wire rst = ~aresetn;

    // ========== CPU SRAM 接口信号 ==========
    wire        inst_sram_en;
    wire [31:0] inst_sram_addr;
    wire [31:0] inst_sram_rdata;
    wire        i_stall;
    
    wire        data_sram_en;
    wire [31:0] data_sram_addr;
    wire [31:0] data_sram_rdata;
    wire [3:0]  data_sram_wen;
    wire [31:0] data_sram_wdata;
    wire        d_stall;
    
    wire        longest_stall;
    wire        other_stall;

    // ========== SRAM-like 接口信号 ==========
    wire        inst_req;
    wire        inst_wr;
    wire [1 :0] inst_size;
    wire [31:0] inst_addr;
    wire [31:0] inst_wdata;
    wire [31:0] inst_rdata;
    wire        inst_addr_ok;
    wire        inst_data_ok;

    wire        data_req;
    wire        data_wr;
    wire [1 :0] data_size;
    wire [31:0] data_addr;
    wire [31:0] data_wdata;
    wire [31:0] data_rdata;
    wire        data_addr_ok;
    wire        data_data_ok;

    // ========== MMU ==========
    wire [31:0] inst_paddr;
    wire [31:0] data_paddr;
    wire no_dcache;
    
    mmu mmu_inst(
        .inst_vaddr(inst_sram_addr),
        .inst_paddr(inst_paddr),
        .data_vaddr(data_sram_addr),
        .data_paddr(data_paddr),
        .no_dcache(no_dcache)
    );

    // ========== CPU 核心 (SRAM 接口) ==========
    mips mips_inst(
        .clk(clk),
        .rst(rst),
        // 指令 SRAM 接口
        .inst_sram_en(inst_sram_en),
        .inst_sram_addr(inst_sram_addr),
        .inst_sram_rdata(inst_sram_rdata),
        .i_stall(i_stall),
        // 数据 SRAM 接口
        .data_sram_en(data_sram_en),
        .data_sram_addr(data_sram_addr),
        .data_sram_rdata(data_sram_rdata),
        .data_sram_wen(data_sram_wen),
        .data_sram_wdata(data_sram_wdata),
        .d_stall(d_stall),
        // 暂停信号
        .longest_stall(longest_stall),
        .other_stall(other_stall),
        // 调试信号
        .debug_wb_pc(debug_wb_pc),
        .debug_wb_rf_wen(debug_wb_rf_wen),
        .debug_wb_rf_wnum(debug_wb_rf_wnum),
        .debug_wb_rf_wdata(debug_wb_rf_wdata)
    );

    // ========== 指令 SRAM -> SRAM-like 转换 ==========
    i_sram_to_sram_like i_sram_to_sram_like_inst(
        .clk(clk), 
        .rst(rst),
        // SRAM 接口
        .inst_sram_en(inst_sram_en),
        .inst_sram_addr(inst_paddr),
        .inst_sram_rdata(inst_sram_rdata),
        .i_stall(i_stall),
        // SRAM-like 接口
        .inst_req(inst_req),
        .inst_wr(inst_wr),
        .inst_size(inst_size),
        .inst_addr(inst_addr),
        .inst_wdata(inst_wdata),
        .inst_addr_ok(inst_addr_ok),
        .inst_data_ok(inst_data_ok),
        .inst_rdata(inst_rdata),
        // 暂停信号
        .longest_stall(longest_stall)
    );

    // ========== 数据 SRAM -> SRAM-like 转换 ==========
    d_sram_to_sram_like d_sram_to_sram_like_inst(
        .clk(clk),
        .rst(rst),
        // SRAM 接口
        .data_sram_en(data_sram_en),
        .data_sram_addr(data_paddr),
        .data_sram_rdata(data_sram_rdata),
        .data_sram_wen(data_sram_wen),
        .data_sram_wdata(data_sram_wdata),
        .d_stall(d_stall),
        // SRAM-like 接口
        .data_req(data_req),
        .data_wr(data_wr),
        .data_size(data_size),
        .data_addr(data_addr),
        .data_wdata(data_wdata),
        .data_addr_ok(data_addr_ok),
        .data_data_ok(data_data_ok),
        .data_rdata(data_rdata),
        // 暂停信号
        .longest_stall(longest_stall)
    );

    // ========== AXI 桥 ==========
    cpu_axi_interface axi_bridge(
        .clk(clk),
        .resetn(aresetn),
        // inst sram-like
        .inst_req(inst_req),
        .inst_wr(inst_wr),
        .inst_size(inst_size),
        .inst_addr(inst_addr),
        .inst_wdata(inst_wdata),
        .inst_rdata(inst_rdata),
        .inst_addr_ok(inst_addr_ok),
        .inst_data_ok(inst_data_ok),
        // data sram-like
        .data_req(data_req),
        .data_wr(data_wr),
        .data_size(data_size),
        .data_addr(data_addr),
        .data_wdata(data_wdata),
        .data_rdata(data_rdata),
        .data_addr_ok(data_addr_ok),
        .data_data_ok(data_data_ok),
        // axi
        .arid(arid),
        .araddr(araddr),
        .arlen(arlen),
        .arsize(arsize),
        .arburst(arburst),
        .arlock(arlock),
        .arcache(arcache),
        .arprot(arprot),
        .arvalid(arvalid),
        .arready(arready),
        .rid(rid),
        .rdata(rdata),
        .rresp(rresp),
        .rlast(rlast),
        .rvalid(rvalid),
        .rready(rready),
        .awid(awid),
        .awaddr(awaddr),
        .awlen(awlen),
        .awsize(awsize),
        .awburst(awburst),
        .awlock(awlock),
        .awcache(awcache),
        .awprot(awprot),
        .awvalid(awvalid),
        .awready(awready),
        .wid(wid),
        .wdata(wdata),
        .wstrb(wstrb),
        .wlast(wlast),
        .wvalid(wvalid),
        .wready(wready),
        .bid(bid),
        .bresp(bresp),
        .bvalid(bvalid),
        .bready(bready)
    );

endmodule
