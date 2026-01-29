`timescale 1ns / 1ps
// top - AXI版本顶层模块
// 架构：mips(SRAM) -> i_sram_to_sram_like/d_sram_to_sram_like -> cpu_axi_interface -> AXI
// 模块名为 top，以匹配 soc_axi_lite_top.v 中的实例化
// 编译用 verilator 则顶层模块需要为mycpu_top
module mycpu_top(
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

    // ========== Bridge_1x2 分流信号 ==========
    // ram路：经过cache
    wire        ram_data_en;
    wire [3:0]  ram_data_wen;
    wire [31:0] ram_data_rdata;
    
    // conf路：不经过cache
    wire        conf_data_en;
    wire [3:0]  conf_data_wen;
    wire [31:0] conf_data_rdata;
    wire [31:0] conf_data_rdata_from_axi;  // 从AXI返回的数据
    wire        conf_data_req;
    wire        conf_data_wr;
    wire [1:0]  conf_data_size;
    wire [31:0] conf_data_addr;
    wire [31:0] conf_data_wdata;
    wire        conf_data_addr_ok;
    wire        conf_data_data_ok;

    // ========== Cache 输出信号 ==========
    // 指令路: i_cache到AXI桥
    wire        inst_req;
    wire        inst_wr;
    wire [1:0]  inst_size;
    wire [31:0] inst_addr;
    wire [31:0] inst_wdata;
    wire [31:0] inst_rdata;
    wire        inst_addr_ok;
    wire        inst_data_ok;
    
    // 数据路: d_cache到bridge_2x1
    wire        cache_data_req;
    wire        cache_data_wr;
    wire [1:0]  cache_data_size;
    wire [31:0] cache_data_addr;
    wire [31:0] cache_data_wdata;
    wire [31:0] cache_data_rdata;
    wire        cache_data_addr_ok;
    wire        cache_data_data_ok;

    // ========== SRAM-like 接口信号 ==========
    // 数据路SRAM-like信号（bridge_2x1输出到AXI桥）
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

    // ========== 根据no_dcache分流数据路 ==========
    // ram路：走cache（no_dcache=0）
    // conf路：不走cache（no_dcache=1）
    
    assign ram_data_en = data_sram_en & ~no_dcache;
    assign ram_data_wen = no_dcache ? 4'b0000 : data_sram_wen;
    assign conf_data_en = data_sram_en & no_dcache;
    assign conf_data_wen = no_dcache ? data_sram_wen : 4'b0000;

    // ========== 指令Cache ==========
    i_cache i_cache_inst(
        .clk(clk), 
        .rst(rst),
        // CPU侧 (SRAM接口)
        .cpu_en(inst_sram_en),
        .cpu_addr(inst_paddr),
        .cpu_rdata(inst_sram_rdata),
        .cpu_stall(i_stall),
        // AXI桥侧 (SRAM-like接口)
        .axi_req(inst_req),
        .axi_wr(inst_wr),
        .axi_size(inst_size),
        .axi_addr(inst_addr),
        .axi_wdata(inst_wdata),
        .axi_addr_ok(inst_addr_ok),
        .axi_data_ok(inst_data_ok),
        .axi_rdata(inst_rdata)
    );

    // ========== 数据Cache (ram路) ==========
    wire ram_d_stall;
    d_cache d_cache_inst(
        .clk(clk),
        .rst(rst),
        // CPU侧 (SRAM接口)
        .cpu_en     (ram_data_en),
        .cpu_wen    (ram_data_wen),
        .cpu_addr   (data_paddr),
        .cpu_wdata  (data_sram_wdata),
        .cpu_rdata  (ram_data_rdata),
        .cpu_stall  (ram_d_stall),
        // AXI桥侧 (SRAM-like接口)
        .axi_req    (cache_data_req),
        .axi_wr     (cache_data_wr),
        .axi_size   (cache_data_size),
        .axi_addr   (cache_data_addr),
        .axi_wdata  (cache_data_wdata),
        .axi_addr_ok(cache_data_addr_ok),
        .axi_data_ok(cache_data_data_ok),
        .axi_rdata  (cache_data_rdata)
    );
    
    // ========== conf路直接转换 ==========
    wire conf_d_stall;
    d_sram_to_sram_like conf_path_inst(
        .clk(clk),
        .rst(rst),
        // SRAM接口 (CPU侧)
        .data_sram_en(conf_data_en),
        .data_sram_addr(data_paddr),
        .data_sram_rdata(conf_data_rdata),
        .data_sram_wen(conf_data_wen),
        .data_sram_wdata(data_sram_wdata),
        .d_stall(conf_d_stall),
        // SRAM-like接口 (AXI桥侧)
        .data_req(conf_data_req),
        .data_wr(conf_data_wr),
        .data_size(conf_data_size),
        .data_addr(conf_data_addr),
        .data_wdata(conf_data_wdata),
        .data_rdata(conf_data_rdata_from_axi),
        .data_addr_ok(conf_data_addr_ok),
        .data_data_ok(conf_data_data_ok),
        // longest_stall信号
        .longest_stall(longest_stall)
    );
    
    // 数据路的rdata和stall合并
    assign data_sram_rdata = no_dcache ? conf_data_rdata : ram_data_rdata;
    assign d_stall = no_dcache ? conf_d_stall : ram_d_stall;

    // ========== Bridge_2x1: 合流cache和conf路的SRAM-like输出 ==========
    bridge_2x1 bridge_2x1_inst(
        .no_dcache        (no_dcache),
        
        .ram_data_req     (cache_data_req),
        .ram_data_wr      (cache_data_wr),
        .ram_data_addr    (cache_data_addr),
        .ram_data_wdata   (cache_data_wdata),
        .ram_data_size    (cache_data_size),
        .ram_data_rdata   (cache_data_rdata),
        .ram_data_addr_ok (cache_data_addr_ok),
        .ram_data_data_ok (cache_data_data_ok),
        
        .conf_data_req     (conf_data_req),
        .conf_data_wr      (conf_data_wr),
        .conf_data_addr    (conf_data_addr),
        .conf_data_wdata   (conf_data_wdata),
        .conf_data_size    (conf_data_size),
        .conf_data_rdata   (conf_data_rdata_from_axi),
        .conf_data_addr_ok (conf_data_addr_ok),
        .conf_data_data_ok (conf_data_data_ok),
        
        .wrap_data_req     (data_req),
        .wrap_data_wr      (data_wr),
        .wrap_data_addr    (data_addr),
        .wrap_data_wdata   (data_wdata),
        .wrap_data_size    (data_size),
        .wrap_data_rdata   (data_rdata),
        .wrap_data_addr_ok (data_addr_ok),
        .wrap_data_data_ok (data_data_ok)
    );
    
    // 将返回数据反馈给conf和cache路
    assign conf_data_rdata_from_axi = data_rdata;

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

    // 指令解码器，用于调试观察指令
    instdec instdec(
        .instr(inst_sram_rdata)
    );

endmodule
