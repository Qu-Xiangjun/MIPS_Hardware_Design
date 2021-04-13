`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2020/05/14 15:07:03
// Design Name: 
// Module Name: mux2
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


module mux2 #(parameter WIDTH = 32 )
    (
    output wire [WIDTH-1:0] dout,
    input wire [WIDTH-1:0] in0,in1,
    input ctl
    );

    assign dout = (ctl == 1) ? in1 : in0 ;
endmodule
