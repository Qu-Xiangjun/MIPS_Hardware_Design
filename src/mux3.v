`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2020/06/22 00:06:43
// Design Name: 
// Module Name: mux3
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


module mux3 #(parameter WIDTH = 8)
    (
        output wire[WIDTH-1:0] dout,
        input wire[WIDTH-1:0] in0,in1,in2,
        input wire[1:0] ctl
    );

    assign dout = (ctl == 2'b00) ? in0 :
                  (ctl == 2'b01) ? in1 :
                  (ctl == 2'b10) ? in2 : in0;
endmodule
