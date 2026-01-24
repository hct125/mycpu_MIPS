`timescale 1ns / 1ps
// mycpu顶层模块

module mycpu_top(
    input wire clk,rst,
    output wire [31:0] mem_wdata,
    output wire [31:0] alu_result,
    output wire data_ram_wea
);

    wire inst_ram_ena,data_ram_ena;
    wire [31:0] pc;
    wire [31:0] instr;
    wire [31:0] mem_rdata; 
    
    mips mips(
        .clk(clk),
        .rst(rst),
        .mem_rdata(mem_rdata),
        .instr(instr),
        .pc(pc),
        .inst_ram_ena(inst_ram_ena),
        .data_ram_ena(data_ram_ena),
        .data_ram_wea(data_ram_wea),
        .alu_result(alu_result),
        .mem_wdata(mem_wdata)
    );

    // 指令RAM地址计算 - 使用字地址
    wire [9:0] pc_addra;
    assign pc_addra = pc[11:2];  // 直接使用PC的字地址部分
    inst_ram instr_ram (.clka(clk),.ena(inst_ram_ena),.addra(pc_addra),.douta(instr));

    // 数据RAM
    data_ram data_ram (.clka(clk),.ena(data_ram_ena),
        .wea({data_ram_wea,data_ram_wea,data_ram_wea,data_ram_wea}),.addra(alu_result[11:2]),
        .dina(mem_wdata),.douta(mem_rdata));

endmodule
