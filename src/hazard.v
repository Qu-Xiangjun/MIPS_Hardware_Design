`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2020/06/01 22:43:30
// Design Name: 
// Module Name: hazard
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module hazard(
    input wire[4:0] rsD, rtD, rsE, rtE, rdE, rdM, writeregE, writeregM, writeregW,
    input wire regwriteE, regwriteM, regwriteW, memtoregD, memtoregE,memtoregM, branchD, jumprD,cp0writeM,
    input wire exceptionoccur,div_stall,i_stall,d_stall,branchE,predict_wrong,
    output wire[1:0] forwardAE, forwardBE,
    output wire forwardAD, forwardBD, forwardcp0dataE,
    output wire stallF, stallD, stallE, stallM, stallW, // ! 重新规划所有的flush和stall信号
    output wire flushF, flushD, flushE, flushM, flushW,  // 保证这些特殊操作可以在hazard里面执行
    output wire longest_stall
    );
    // TODO: 注意Load指令后面加jr、branch类型指令的数据前推未解决

    // 数据前推处理 如果寄存器号对上了就可以前推 
    // 注意：如果寄存器号为0 不需要前推

    assign forwardAE = ((rsE != 5'b0) & (rsE == writeregM) & regwriteM) ? 2'b10:
                        ((rsE != 5'b0) & (rsE == writeregW) & regwriteW) ? 2'b01: 2'b00;
    assign forwardBE = ((rtE != 2'b0) & (rtE == writeregM) & regwriteM) ? 2'b10:
                        ((rtE != 5'b0) & (rtE == writeregW) & regwriteW) ? 2'b01: 2'b00;

    assign forwardAD = (rsD != 5'b0) & (rsD == writeregM) & regwriteM;
    assign forwardBD = (rtD != 5'b0) & (rtD == writeregM) & regwriteM;

    // mtc0 mfc0冲突
	assign forwardcp0dataE = (rdE && (rdE == rdM) && cp0writeM);

    // 流水线暂停 lw操作需要读存储器 所以必须进行暂停操作
    wire lwstall, branchstall, jrstall;
    // TODO: 增加 lw--jumprD型指令的二次stall，未经测试   & ~memtoregD
    assign lwstall = (((rsD == rtE) | (rtD == rtE)) & memtoregE) | ((rsD != 5'b0) & (rsD == writeregM) & memtoregM & jumprD);
    assign branchstall = branchD & regwriteE & ((writeregE == rsD) | (writeregE == rtD)) |
                         branchD & memtoregM & ((writeregM == rsD) | (writeregM == rtD));
    
    // 由于branch已经由分支预测处理了 所以只需要使用lwstall单处理jumprD
    assign jrstall = jumprD & regwriteE & ((writeregE == rsD) | (writeregE == rtD)); //|
    //                     jumprD & memtoregM & ((writeregM == rsD) | (writeregM == rtD));
    
    assign longest_stall = i_stall | d_stall | div_stall;

    assign stallF = (longest_stall | lwstall | jrstall) & ~exceptionoccur;
    assign stallD = longest_stall | lwstall | jrstall;
    assign stallE = longest_stall;
    assign stallM = longest_stall;
    assign stallW = longest_stall;

    assign flushF = 1'b0;
    assign flushD = ((branchE & predict_wrong) | exceptionoccur) & (~longest_stall);
    assign flushE = (lwstall | jrstall         | exceptionoccur) & (~longest_stall); // TODO:exceptionoccur信号用于异常时清除所有的寄存器，还未完全测试
    assign flushM = (exceptionoccur                            ) & (~longest_stall);
    assign flushW = (exceptionoccur                            ) & (~longest_stall);

endmodule
