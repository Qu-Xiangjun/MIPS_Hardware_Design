`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2020/05/13 23:36:29
// Design Name: 
// Module Name: pc
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


module pc(
    input clk,
    input rst,en,
    input [31:0] pc_in,
    output reg [31:0] pc_out,
    output reg [31:0] inst_ce
    );

    initial begin
        pc_out = 32'hbfc00000;
        inst_ce = 32'hbfc00000;
    end

    always@(posedge clk) begin
        if(rst) begin
            pc_out <= 32'hbfc00000;
            inst_ce <= 32'hbfc00000;
        end
        else if(en) begin
            pc_out <= pc_in;
            inst_ce <= pc_in;
        end
    end
endmodule
