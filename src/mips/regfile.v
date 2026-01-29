`timescale 1ns / 1ps
//寄存器堆模块：读数据为组合逻辑，两个读地址读出两个数据；写数据为时序逻辑，写使能控制
(* keep_hierarchy = "yes" *)
module regfile(
	input wire clk,
	input wire we3,                //写使能
	input wire[4:0] ra1,ra2,wa3,   //ra1、ra2为读的地址，wa3为写的地址
	input wire[31:0] wd3, 	        //写数据
	output wire[31:0] rd1,rd2 	    //读数据
    );
	reg [31:0] rf[31:0];           //寄存器堆
	//写是时序逻辑
	always @(negedge clk) begin
		if(we3) begin
			rf[wa3] <= wd3;
		end
	end

	wire [31:0] rf0 = rf[0];
	wire [31:0] rf1 = rf[1];
	wire [31:0] rf2 = rf[2];
	wire [31:0] rf3 = rf[3];
	wire [31:0] rf4 = rf[4];  //观察信号

	//读是组合逻辑
	assign rd1 = (ra1 != 0) ? rf[ra1] : 0;  //0号寄存器留给0
	assign rd2 = (ra2 != 0) ? rf[ra2] : 0;
endmodule
