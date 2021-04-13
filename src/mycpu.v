`timescale 1ns / 1ps
module mycpu (
    input clk,rst,
    input [5:0] int,

    //instr
    output wire inst_req,
    output wire inst_wr,
    output wire [1:0] inst_size,
    output wire [31:0] inst_addr,
    output wire [31:0] inst_wdata,
    input wire inst_addr_ok,
    input wire inst_data_ok,
    input wire [31:0] inst_rdata,

    //data
    output wire data_req,
    output wire data_wr,
    output wire [1:0] data_size,
    output wire [31:0] data_addr,
    output wire [31:0] data_wdata,
    input wire data_addr_ok,
    input wire data_data_ok,
    input wire [31:0] data_rdata,

    //debug
    output [31:0] debug_wb_pc     ,
    output [3:0] debug_wb_rf_wen  ,
    output [4:0] debug_wb_rf_wnum ,
    output [31:0] debug_wb_rf_wdata
);
    //instr
    wire  inst_sram_en;
    wire  [3:0] inst_sram_wen    ;
    wire  [31:0] inst_sram_addr  ;
    wire  [31:0] inst_sram_wdata ;
    wire [31:0] inst_sram_rdata  ; 

    //data
    wire  data_sram_en           ;
    wire  [3:0] data_sram_wen    ;
    wire  [31:0] data_sram_addr  ;
    wire  [31:0] data_sram_wdata ;
    wire  [31:0] data_sram_rdata ;

    //stall
    wire i_stall,d_stall,longest_stall;

    assign inst_sram_wen = 4'b0;
    assign inst_sram_wdata = 32'b0;
    // wire[31:0] data_sram_addr_temp;
    
    // TODO inst_en = 1;
    // 如果需要 更改为inst_enF(inst_sram_en),

    wire [31:0] cpu_inst_addr;
    wire [31:0] cpu_data_addr;
    // wire no_dcache;

    // mmu my_addr_translate(.inst_vaddr(cpu_inst_addr),.inst_paddr(inst_sram_addr),
    // .data_vaddr(cpu_data_addr),.data_paddr(data_sram_addr),.no_dcache(no_dcache));

    // assign inst_sram_en = 1'b1;

    assign inst_sram_addr  = cpu_inst_addr;
    assign data_sram_addr = cpu_data_addr;

    flowmips datapath(
        .clk(clk), .rst(rst), // low active ! 为了外部修改了
        .int(int),

        //inst
        .inst_sram_en(inst_sram_en), // TODO: 有可能assign en = 1
        .pc(cpu_inst_addr),
        .instr(inst_sram_rdata),

        //data
        .memwriteM(data_sram_en),
        .aluoutM(cpu_data_addr),
        .WriteDataM(data_sram_wdata),
        .readdata(data_sram_rdata),
        .selM(data_sram_wen),

        // stall
        .i_stall(i_stall),
        .d_stall(d_stall),
        .longest_stall(longest_stall),

        .debug_wb_pc       (debug_wb_pc       ),  
        .debug_wb_rf_wen   (debug_wb_rf_wen   ),  
        .debug_wb_rf_wnum  (debug_wb_rf_wnum  ),  
        .debug_wb_rf_wdata (debug_wb_rf_wdata )  
    );

    //inst sram to sram-like
    i_sram2sraml i_sram_to_sram_like(
        .clk(clk), .rst(rst),
        //sram
        .inst_sram_en(inst_sram_en),
        .inst_sram_addr(inst_sram_addr),
        .inst_sram_rdata(inst_sram_rdata),
        .i_stall(i_stall),
        .longest_stall(longest_stall),

        //sram like
        .inst_req(inst_req), 
        .inst_wr(inst_wr),
        .inst_size(inst_size),
        .inst_addr(inst_addr),   
        .inst_wdata(inst_wdata),
        .inst_addr_ok(inst_addr_ok),
        .inst_data_ok(inst_data_ok),
        .inst_rdata(inst_rdata)
    );

    //data sram to sram-like
    d_sram2sraml d_sram_to_sram_like(
        .clk(clk), .rst(rst),
        //sram
        .data_sram_en(data_sram_en),
        .data_sram_addr(data_sram_addr),
        .data_sram_rdata(data_sram_rdata),
        .data_sram_wen(data_sram_wen),
        .data_sram_wdata(data_sram_wdata),
        .d_stall(d_stall),
        .longest_stall(longest_stall),

        //sram like
        .data_req(data_req),    
        .data_wr(data_wr),
        .data_size(data_size),
        .data_addr(data_addr),   
        .data_wdata(data_wdata),
        .data_addr_ok(data_addr_ok),
        .data_data_ok(data_data_ok),
        .data_rdata(data_rdata)
    );

    // BUG fix for addr translate 已找到参考资料中的mmu模块转换地址
    // assign data_sram_addr = data_sram_addr_temp[31:16] == 16'hbfaf ? {3'b0, data_sram_addr_temp[28:0]} : data_sram_addr_temp;
endmodule