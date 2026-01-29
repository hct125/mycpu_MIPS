// 指令缓存设计
`timescale 1ns / 1ps

(* keep_hierarchy = "yes" *)
module i_cache(
    input wire clk, rst,
    // CPU 侧接口
    input  wire        cpu_en,      // inst_sram_en
    input  wire [31:0] cpu_addr,    // inst_sram_addr
    output wire [31:0] cpu_rdata,   // inst_sram_rdata
    output wire        cpu_stall,   // i_stall
    // AXI 桥侧接口
    output reg         axi_req,     // inst_req
    output wire        axi_wr,      // inst_wr(恒为0)
    output wire [1:0]  axi_size,    // inst_size
    output reg  [31:0] axi_addr,    // inst_addr
    output wire [31:0] axi_wdata,   // inst_wdata
    input  wire        axi_addr_ok, // inst_addr_ok
    input  wire        axi_data_ok, // inst_data_ok
    input  wire [31:0] axi_rdata    // inst_rdata
);

    // 配置参数：4字节 = 8位索引，4位偏移，20位标签；
    localparam INDEX_WIDTH = 8;
    localparam OFFSET_WIDTH = 4;
    localparam TAG_WIDTH = 32 - INDEX_WIDTH - OFFSET_WIDTH;
    localparam LINE_NUM = 1 << INDEX_WIDTH; // 256
    
    // 内部存储 - 使用 (* ram_style = "distributed" *) 属性
    (* ram_style = "distributed" *) reg [TAG_WIDTH-1:0] tag_mem [0:LINE_NUM-1];
    reg valid_mem [0:LINE_NUM-1];
    (* ram_style = "distributed" *) reg [127:0] icache_data [0:LINE_NUM-1];
    
    // 地址分解
    wire [TAG_WIDTH-1:0] cpu_tag   = cpu_addr[31:12];
    wire [INDEX_WIDTH-1:0] cpu_index = cpu_addr[11:4];
    wire [OFFSET_WIDTH-1:0] cpu_offset= cpu_addr[3:0];
    
    // 命中判定
    wire hit;
    (* keep = "true" *) wire [127:0] line_data;
    assign line_data = icache_data[cpu_index];
    wire [TAG_WIDTH-1:0] saved_tag = tag_mem[cpu_index];
    wire valid = valid_mem[cpu_index];
    // CPU请求有效 & Tag匹配 & Valid为1 = 命中
    assign hit = cpu_en && valid && (saved_tag == cpu_tag);

    // 读取数据：根据索引进行选择
    (* keep = "true" *) wire [31:0] cpu_rdata_internal;
    assign cpu_rdata_internal = (cpu_offset[3:2] == 2'b00) ? line_data[31:0] :
                                (cpu_offset[3:2] == 2'b01) ? line_data[63:32] :
                                (cpu_offset[3:2] == 2'b10) ? line_data[95:64] :
                                                             line_data[127:96];
    assign cpu_rdata = cpu_rdata_internal;
    
    // 状态机：处理缺失重填
    localparam IDLE = 0, REFILL_REQ = 1, REFILL_WAIT = 2;
    reg [1:0] state;
    reg [2:0] refill_cnt; // 记录重填了第几个字(0-3)

    // AXI 接口固定输出
    assign axi_wr = 1'b0;    // 指令Cache只读
    assign axi_size = 2'b10; // 每次读4字节
    assign axi_wdata = 32'b0;

    always @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
            refill_cnt <= 0;
            axi_req <= 0;
        end else begin
            case (state)
                IDLE: begin
                    // 如果CPU请求且未命中，开始重填
                    if (cpu_en && !hit) begin
                        state <= REFILL_REQ;
                        refill_cnt <= 0;
                        // 准备发送第一个请求：地址对齐到行首
                        axi_addr <= {cpu_addr[31:4], 4'b0000}; 
                        axi_req <= 1;
                    end
                end

                REFILL_REQ: begin
                    // 等待地址握手成功
                    if (axi_addr_ok) begin
                        axi_req <= 0;
                        state <= REFILL_WAIT;
                    end
                end

                REFILL_WAIT: begin
                    // 等待数据回来
                    if (axi_data_ok) begin
                        // 写入对应的字
                        if (refill_cnt == 0) icache_data[cpu_index][31:0]   <= axi_rdata;
                        if (refill_cnt == 1) icache_data[cpu_index][63:32]  <= axi_rdata;
                        if (refill_cnt == 2) icache_data[cpu_index][95:64]  <= axi_rdata;
                        if (refill_cnt == 3) icache_data[cpu_index][127:96] <= axi_rdata;

                        if (refill_cnt == 3) begin
                            // 填满了一行，更新Tag和Valid
                            tag_mem[cpu_index] <= cpu_tag;
                            valid_mem[cpu_index] <= 1;
                            state <= IDLE; // 回到IDLE，下一拍就会Hit
                        end else begin
                            // 还没填满，请求下一个字
                            refill_cnt <= refill_cnt + 1;
                            axi_addr <= axi_addr + 4;
                            axi_req <= 1;
                            state <= REFILL_REQ;
                        end
                    end
                end
            endcase
        end
    end
    
    // 初始化 Valid 数组
    integer i;
    initial begin
        for(i=0; i<LINE_NUM; i=i+1) valid_mem[i] = 0;
    end

    // Stall 信号：如果 CPU 请求了但没命中，就暂停流水线
    assign cpu_stall = cpu_en && !hit;

endmodule