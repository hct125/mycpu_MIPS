`timescale 1ns / 1ps

module mycpu_top(
	input wire clk,rst,
    output wire [31:0] mem_wdata,
    output wire [31:0] alu_result,
    output wire [3:0] data_ram_wea
    );

	wire inst_ram_ena,data_ram_ena;
	wire [31:0] pc;
    wire [31:0] instr;
    wire [31:0] mem_rdata; 
    
	mips mips(.clk(clk),.rst(rst),.mem_rdata(mem_rdata),.instr(instr),.pc(pc),.inst_ram_ena(inst_ram_ena),
        .data_ram_ena(data_ram_ena),.data_ram_wea(data_ram_wea),.alu_result(alu_result),
        .mem_wdata(mem_wdata)
    );

    wire [9:0] pc_addra;
    assign pc_addra = (pc-4)>>2;
    inst_ram instr_ram (.clka(clk),.ena(inst_ram_ena),.addra(pc_addra),.douta(instr));

    //data_ram
    data_ram data_ram (.clka(clk),.ena(data_ram_ena),
        .wea(data_ram_wea), 
        .addra(alu_result[11:2]),
        .dina( (data_ram_wea == 4'b1111) ? mem_wdata : 
               (data_ram_wea == 4'b1100 || data_ram_wea == 4'b0011) ? {2{mem_wdata[15:0]}} : 
               {4{mem_wdata[7:0]}} ),
        .douta(mem_rdata));

endmodule