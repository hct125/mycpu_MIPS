`timescale 1ns / 1ps
//SoC top
module top(
	input clk,reset,
    output reg [9:0] pc,
    output reg [39:0] ascii,
    output reg [31:0] alu_result,instr,readdata,writedata
    );

	wire memwrite;

    wire        inst_en;     //如果有inst_en，就用inst_en
    wire [3:0]  inst_wen = 4'b0;
    wire [31:0] inst_addr = pc;   //IP核初始化为字地址
    wire [31:0] inst_wdata = 32'b0;
    wire [31:0] inst_rdata;
    assign instr = inst_rdata;

    wire        data_en;     //如果有data_en，就用data_en
    wire [3:0]  data_wen = {4{memwrite}};
    wire [31:0] data_addr = alu_result;
    wire [31:0] data_wdata = writedata;
    wire [31:0] data_rdata;
    assign readdata = data_rdata;



    //CPU核
    mips mips(
        .clk(clk),
        .rst(~reset),     //reset高电平复位
        .instr(instr),              //instrF
        .mem_rdata(readdata),
        //outputs
        .pc(pc),                    //pcF
        .inst_ram_ena(inst_en),
        .data_ram_ena(data_en),
        .data_ram_wea(memwrite),
        .alu_result(alu_result),
        .mem_wdata(writedata)
    );

    //inst ram
    inst_ram inst_ram
    (
        .clka  (~clk           ),   
        .ena   (inst_en        ),
        .wea   (inst_wen       ),
        .addra (inst_addr      ),
        .dina  (inst_wdata     ),
        .douta (inst_rdata     ) 
    );

    //data ram
    data_ram data_ram
    (
        .clka  (~clk            ),   
        .ena   (data_en         ),
        .wea   (data_wen        ),
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