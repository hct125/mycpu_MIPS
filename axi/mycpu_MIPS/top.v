`timescale 1ns / 1ps
// mycpu_top - SoC
module mycpu_top(
    input wire aclk,
    input wire aresetn,
    input wire [5:0] ext_int,

    // AXI
    // ar
    output wire [3 :0] arid,
    output wire [31:0] araddr,
    output wire [3 :0] arlen,
    output wire [2 :0] arsize,
    output wire [1 :0] arburst,
    output wire [1 :0] arlock,
    output wire [3 :0] arcache,
    output wire [2 :0] arprot,
    output wire        arvalid,
    input  wire        arready,
    // r
    input  wire [3 :0] rid,
    input  wire [31:0] rdata,
    input  wire [1 :0] rresp,
    input  wire        rlast,
    input  wire        rvalid,
    output wire        rready,
    // aw
    output wire [3 :0] awid,
    output wire [31:0] awaddr,
    output wire [3 :0] awlen,
    output wire [2 :0] awsize,
    output wire [1 :0] awburst,
    output wire [1 :0] awlock,
    output wire [3 :0] awcache,
    output wire [2 :0] awprot,
    output wire        awvalid,
    input  wire        awready,
    // w
    output wire [3 :0] wid,
    output wire [31:0] wdata,
    output wire [3 :0] wstrb,
    output wire        wlast,
    output wire        wvalid,
    input  wire        wready,
    // b
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

    wire [31:0] pc;
    wire [31:0] data_addr;
    
    // SRAM-like -> AXI bridge signals
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
    wire [31:0] data_addr_sram;
    wire [31:0] data_wdata_sram;
    wire [31:0] data_rdata_sram;
    wire [3 :0] data_ram_wea;
    wire        data_addr_ok;
    wire        data_data_ok;
    
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
    
    assign inst_addr = inst_paddr;
    assign data_addr_sram = data_paddr;
    
    // CPU  Block RAM 
    wire inst_ram_ena_internal;
    mips mips(
        .clk(aclk),                  // 与AXI同相位
        .rst(~aresetn),              // resetn高电平有效
        .instr(inst_rdata),
        .mem_rdata(data_rdata_sram),
        .inst_data_ok(inst_data_ok),
        .data_data_ok(data_data_ok),

        .pc(pc),
        .inst_ram_ena(inst_ram_ena_internal),
        .data_ram_ena(data_req),
        .data_ram_wea(data_ram_wea),
        .data_size(data_size),
        .alu_result(data_addr),
        .mem_wdata(data_wdata_sram),
        // debug
        .debug_wb_pc(debug_wb_pc),
        .debug_wb_rf_wen(debug_wb_rf_wen),
        .debug_wb_rf_wnum(debug_wb_rf_wnum),
        .debug_wb_rf_wdata(debug_wb_rf_wdata)
    );

    assign inst_req = inst_ram_ena_internal;
    assign inst_wr = 1'b0;
    assign inst_size = 2'b10;
    assign inst_wdata = 32'b0;

    assign data_wr = |data_ram_wea;

    cpu_axi_interface axi_bridge(
        .clk(aclk),
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
        .data_addr(data_addr_sram),
        .data_wdata(data_wdata_sram),
        .data_rdata(data_rdata_sram),
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