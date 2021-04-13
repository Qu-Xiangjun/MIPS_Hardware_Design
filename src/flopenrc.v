`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2020/05/30 23:38:30
// Design Name: 
// Module Name: flopenrc
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


module flopenrc #(parameter WIDTH = 8)
    (   input clk,reset,en,clear,
        input [WIDTH-1:0] d,
        output reg[WIDTH-1:0] q
    );
    
    always@(posedge clk) begin
        if(reset) q <= 0;
        else if(clear) q <= 0;
        else if(en) q <= d;
    end
endmodule
