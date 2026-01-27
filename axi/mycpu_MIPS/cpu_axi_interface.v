/*------------------------------------------------------------------------------
--------------------------------------------------------------------------------
Copyright (c) 2016, Loongson Technology Corporation Limited.

All rights reserved.

Redistribution and use in source and binary forms, with or without modification,
are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this 
list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice, 
this list of conditions and the following disclaimer in the documentation and/or
other materials provided with the distribution.

3. Neither the name of Loongson Technology Corporation Limited nor the names of 
its contributors may be used to endorse or promote products derived from this 
software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND 
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED 
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE 
DISCLAIMED. IN NO EVENT SHALL LOONGSON TECHNOLOGY CORPORATION LIMITED BE LIABLE
TO ANY PARTY FOR DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE 
GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) 
HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT 
LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF
THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
--------------------------------------------------------------------------------
------------------------------------------------------------------------------*/

module cpu_axi_interface
(
    input         clk,
    input         resetn, 

    //inst sram-like 
    input         inst_req     ,
    input         inst_wr      ,
    input  [1 :0] inst_size    ,
    input  [31:0] inst_addr    ,
    input  [31:0] inst_wdata   ,
    output [31:0] inst_rdata   ,
    output        inst_addr_ok ,
    output        inst_data_ok ,
    
    //data sram-like 
    input         data_req     ,
    input         data_wr      ,
    input  [1 :0] data_size    ,
    input  [31:0] data_addr    ,
    input  [31:0] data_wdata   ,
    output [31:0] data_rdata   ,
    output        data_addr_ok ,
    output        data_data_ok ,

    //axi
    //ar
    output [3 :0] arid         ,
    output [31:0] araddr       ,
    output [3 :0] arlen        ,
    output [2 :0] arsize       ,
    output [1 :0] arburst      ,
    output [1 :0] arlock        ,
    output [3 :0] arcache      ,
    output [2 :0] arprot       ,
    output        arvalid      ,
    input         arready      ,
    //r           
    input  [3 :0] rid          ,
    input  [31:0] rdata        ,
    input  [1 :0] rresp        ,
    input         rlast        ,
    input         rvalid       ,
    output        rready       ,
    //aw          
    output [3 :0] awid         ,
    output [31:0] awaddr       ,
    output [3 :0] awlen        ,
    output [2 :0] awsize       ,
    output [1 :0] awburst      ,
    output [1 :0] awlock       ,
    output [3 :0] awcache      ,
    output [2 :0] awprot       ,
    output        awvalid      ,
    input         awready      ,
    //w          
    output [3 :0] wid          ,
    output [31:0] wdata        ,
    output [3 :0] wstrb        ,
    output        wlast        ,
    output        wvalid       ,
    input         wready       ,
    //b           
    input  [3 :0] bid          ,
    input  [1 :0] bresp        ,
    input         bvalid       ,
    output        bready       
);
//addr
reg do_req;
reg do_req_or; //req is inst or data;1:data,0:inst
reg        do_wr_r;
reg [1 :0] do_size_r;
reg [31:0] do_addr_r;
reg [31:0] do_wdata_r;
reg        data_pending;
reg        pend_wr_r;
reg [1 :0] pend_size_r;
reg [31:0] pend_addr_r;
reg [31:0] pend_wdata_r;
wire data_back;
wire write_back;
wire read_back;

assign inst_addr_ok = !do_req && !data_pending;
assign data_addr_ok = !do_req && !data_pending;
always @(posedge clk)
begin
    if (!resetn) begin
        do_req       <= 1'b0;
        do_req_or    <= 1'b0;
        do_wr_r      <= 1'b0;
        do_size_r    <= 2'b0;
        do_addr_r    <= 32'b0;
        do_wdata_r   <= 32'b0;
        data_pending <= 1'b0;
        pend_wr_r    <= 1'b0;
        pend_size_r  <= 2'b0;
        pend_addr_r  <= 32'b0;
        pend_wdata_r <= 32'b0;
    end else begin
        // capture pending data request if bus is busy
        if (data_req && do_req && !data_pending) begin
            data_pending <= 1'b1;
            pend_wr_r    <= data_wr;
            pend_size_r  <= data_size;
            pend_addr_r  <= data_addr;
            pend_wdata_r <= data_wdata;
        end

        // complete current request
        if (data_back) begin
            do_req <= 1'b0;
        end

        // issue next request when idle
        if (!do_req) begin
            if (data_pending) begin
                do_req       <= 1'b1;
                do_req_or    <= 1'b1;
                do_wr_r      <= pend_wr_r;
                do_size_r    <= pend_size_r;
                do_addr_r    <= pend_addr_r;
                do_wdata_r   <= pend_wdata_r;
                data_pending <= 1'b0;
            end else if (inst_req) begin
                do_req     <= 1'b1;
                do_req_or  <= 1'b0;
                do_wr_r    <= inst_wr;
                do_size_r  <= inst_size;
                do_addr_r  <= inst_addr;
                do_wdata_r <= inst_wdata;
            end else if (data_req) begin
                do_req     <= 1'b1;
                do_req_or  <= 1'b1;
                do_wr_r    <= data_wr;
                do_size_r  <= data_size;
                do_addr_r  <= data_addr;
                do_wdata_r <= data_wdata;
            end
        end
    end
end

//inst sram-like
assign inst_data_ok = do_req&&!do_req_or&&data_back;
assign data_data_ok = do_req&& do_req_or&&data_back;
assign inst_rdata   = rdata;
assign data_rdata   = rdata;

//---axi
reg addr_rcv;
reg wdata_rcv;

assign write_back = addr_rcv && wdata_rcv;
// 允许读返回与地址握手同周期，避免零等待RAM卡死
assign read_back  = rvalid && rready;
assign data_back  = do_wr_r ? write_back : read_back;
always @(posedge clk)
begin
    addr_rcv  <= !resetn           ? 1'b0 :
                 data_back         ? 1'b0 :
                 (arvalid&&arready ? 1'b1 :
                  awvalid&&awready ? 1'b1 : addr_rcv);
    wdata_rcv <= !resetn        ? 1'b0 :
                 data_back      ? 1'b0 :
                 (wvalid&&wready ? 1'b1 : wdata_rcv);
end
//ar
assign arid    = 4'd0;
assign araddr  = do_addr_r;
assign arlen   = 4'd0;
assign arsize  = {1'b0, do_size_r};
assign arburst = 2'b01;
assign arlock  = 2'd0;
assign arcache = 4'd0;
assign arprot  = 3'd0;
assign arvalid = do_req&&!do_wr_r&&!addr_rcv;
//r
assign rready  = 1'b1;

//aw
assign awid    = 4'd0;
assign awaddr  = do_addr_r;
assign awlen   = 4'd0;
assign awsize  = {1'b0, do_size_r};
assign awburst = 2'b01;
assign awlock  = 2'd0;
assign awcache = 4'd0;
assign awprot  = 3'd0;
assign awvalid = do_req&&do_wr_r&&!addr_rcv;
//w
assign wid    = 4'd0;
assign wdata  = do_wdata_r;
assign wstrb  = do_size_r==2'd0 ? 4'b0001<<do_addr_r[1:0] :
                do_size_r==2'd1 ? 4'b0011<<do_addr_r[1:0] : 4'b1111;
assign wlast  = 1'd1;
assign wvalid = do_req&&do_wr_r&&!wdata_rcv;
//b
assign bready  = 1'b1;

endmodule

