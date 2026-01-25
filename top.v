`timescale 1ns / 1ps
//SoC top
module top(
	input clk,reset,
    output reg [31:0] pc,
    output reg [39:0] ascii,
    output reg [31:0] alu_result,instr,mem_rdata,mem_wdata
    );

    wire        inst_ram_ena;     //如果有inst_en，就用inst_en
    wire [3:0]  inst_ram_wea = 4'b0;
    wire [31:0] inst_addr = pc;   //IP核初始化为字节地址
    wire [31:0] inst_wdata = 32'b0;
    wire [31:0] inst_rdata;
    assign instr = inst_rdata;

    wire        data_ram_ena;     //如果有data_en，就用data_en
    wire [3:0]  data_ram_wea;
    wire [31:0] data_addr = alu_result;
    wire [31:0] data_wdata;
    wire [31:0] data_rdata;

    assign data_wdata = (data_ram_wea == 4'b1111) ? mem_wdata : 
                        (data_ram_wea == 4'b1100 || data_ram_wea == 4'b0011) ? {2{mem_wdata[15:0]}} : 
                        {4{mem_wdata[7:0]}};
    assign mem_rdata = data_rdata;



    //CPU核
    mips mips(
        .clk(clk),
        .rst(~reset),     //reset高电平复位
        .instr(instr),              //instrF
        .mem_rdata(mem_rdata),
        //outputs
        .pc(pc),                    //pcF
        .inst_ram_ena(inst_ram_ena),
        .data_ram_ena(data_ram_ena),
        .data_ram_wea(data_ram_wea),
        .alu_result(alu_result),
        .mem_wdata(mem_wdata)
    );

    //inst ram
    inst_ram inst_ram
    (
        .clka  (~clk           ),   
        .ena   (inst_ram_ena   ),
        .wea   (inst_ram_wea   ),
        .addra (inst_addr      ),
        .dina  (inst_wdata     ),
        .douta (inst_rdata     ) 
    );

    //data ram
    data_ram data_ram
    (
        .clka  (~clk            ),   
        .ena   (data_ram_ena    ),
        .wea   (data_ram_wea    ),
        .addra (data_addr       ),
        .dina  (data_wdata      ),
        .douta (data_rdata      ) 
    );

    //ascii
    instdec instdec(
        .instr(instr),
        .ascii(ascii)
    );
endmodule