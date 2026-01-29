// 数据缓存设计
`timescale 1ns / 1ps

module d_cache(
    input wire clk, rst,
    // CPU 侧接口
    input  wire        cpu_en,      // data_sram_en
    input  wire [3:0]  cpu_wen,     // data_sram_wen
    input  wire [31:0] cpu_addr,    // data_sram_addr
    input  wire [31:0] cpu_wdata,   // data_sram_wdata
    output wire [31:0] cpu_rdata,   // data_sram_rdata
    output wire        cpu_stall,   // d_stall
    // AXI 桥侧接口
    output reg         axi_req,     // data_req
    output reg         axi_wr,      // data_wr
    output reg  [1:0]  axi_size,    // data_size
    output reg  [31:0] axi_addr,    // data_addr
    output reg  [31:0] axi_wdata,   // data_wdata
    input  wire        axi_addr_ok,
    input  wire        axi_data_ok,
    input  wire [31:0] axi_rdata
);

    // 配置参数
    localparam INDEX_WIDTH = 8;
    localparam OFFSET_WIDTH = 4;
    localparam TAG_WIDTH = 32 - INDEX_WIDTH - OFFSET_WIDTH;
    localparam LINE_NUM = 256;
    reg [TAG_WIDTH-1:0] tag_mem [0:LINE_NUM-1];
    reg                 valid_mem [0:LINE_NUM-1];
    reg [127:0]         data_mem [0:LINE_NUM-1];
    wire [TAG_WIDTH-1:0] cpu_tag    = cpu_addr[31:12];
    wire [INDEX_WIDTH-1:0] cpu_index  = cpu_addr[11:4];
    wire [OFFSET_WIDTH-1:0] cpu_offset = cpu_addr[3:0];

    // 命中判定
    wire hit;
    wire [127:0] line_data = data_mem[cpu_index];
    wire valid = valid_mem[cpu_index];
    // 写请求不看hit信号，直接去 AXI
    assign hit = cpu_en && (cpu_wen == 0) && valid && (tag_mem[cpu_index] == cpu_tag);
    // 读取逻辑
    assign cpu_rdata = (cpu_offset[3:2] == 2'b00) ? line_data[31:0] :
                       (cpu_offset[3:2] == 2'b01) ? line_data[63:32] :
                       (cpu_offset[3:2] == 2'b10) ? line_data[95:64] :
                                                    line_data[127:96];
    // 状态机
    localparam IDLE = 0, REFILL_REQ = 1, REFILL_WAIT = 2, WRITE_REQ = 3, WRITE_WAIT = 4;
    reg [2:0] state;
    reg [2:0] refill_cnt;
    // 判断是不是写操作
    wire is_write = cpu_en && (|cpu_wen);
    // 判断AXI的写 size
    wire [1:0] write_size = (cpu_wen==4'b0001 || cpu_wen==4'b0010 || cpu_wen==4'b0100 || cpu_wen==4'b1000) ? 2'b00 :
                            (cpu_wen==4'b0011 || cpu_wen==4'b1100) ? 2'b01 : 2'b10;
    always @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
            refill_cnt <= 0;
            axi_req <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (cpu_en) begin
                        if (is_write) begin
                            // 写穿透：直接发给AXI
                            state <= WRITE_REQ;
                            axi_req <= 1;
                            axi_wr <= 1;
                            axi_size <= write_size;
                            axi_addr <= cpu_addr;
                            axi_wdata <= cpu_wdata;
                            // 如果命中了 Cache，同时也更新 Cache
                            if (valid && (tag_mem[cpu_index] == cpu_tag)) begin
                                if (cpu_wen[0]) data_mem[cpu_index][cpu_offset*8 +: 8] <= cpu_wdata[7:0];
                                if (cpu_wen[1]) data_mem[cpu_index][cpu_offset*8+8 +: 8] <= cpu_wdata[15:8];
                                if (cpu_wen[2]) data_mem[cpu_index][cpu_offset*8+16 +: 8] <= cpu_wdata[23:16];
                                if (cpu_wen[3]) data_mem[cpu_index][cpu_offset*8+24 +: 8] <= cpu_wdata[31:24];
                            end
                        end 
                        else if (!hit) begin
                            // 读缺失：发起重填
                            state <= REFILL_REQ;
                            refill_cnt <= 0;
                            axi_req <= 1;
                            axi_wr <= 0;
                            axi_size <= 2'b10; // 读字
                            axi_addr <= {cpu_addr[31:4], 4'b0000}; // 对齐
                        end
                    end
                end

                REFILL_REQ: begin
                    if (axi_addr_ok) begin
                        axi_req <= 0;
                        state <= REFILL_WAIT;
                    end
                end

                REFILL_WAIT: begin
                    if (axi_data_ok) begin
                        if (refill_cnt == 0) data_mem[cpu_index][31:0]   <= axi_rdata;
                        if (refill_cnt == 1) data_mem[cpu_index][63:32]  <= axi_rdata;
                        if (refill_cnt == 2) data_mem[cpu_index][95:64]  <= axi_rdata;
                        if (refill_cnt == 3) data_mem[cpu_index][127:96] <= axi_rdata;

                        if (refill_cnt == 3) begin
                            tag_mem[cpu_index] <= cpu_tag;
                            valid_mem[cpu_index] <= 1;
                            state <= IDLE;
                        end else begin
                            refill_cnt <= refill_cnt + 1;
                            axi_addr <= axi_addr + 4;
                            axi_req <= 1;
                            state <= REFILL_REQ;
                        end
                    end
                end

                WRITE_REQ: begin
                    if (axi_addr_ok) begin
                        axi_req <= 0;
                        state <= WRITE_WAIT;
                    end
                end

                WRITE_WAIT: begin
                    if (axi_data_ok) begin
                        state <= IDLE; // 写完成
                    end
                end
            endcase
        end
    end
    
    // 初始化 valid
    integer j;
    initial begin
        for(j=0; j<LINE_NUM; j=j+1) valid_mem[j] = 0;
    end

    // Stall 信号：读不命中，或者正在写操作时，都要 Stall
    assign cpu_stall = (cpu_en && !hit && !is_write) || (state != IDLE); 

endmodule