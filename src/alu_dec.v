`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2020/05/14 00:10:57
// Design Name: 
// Module Name: alu_dec
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

`include "defines.vh"
/*
 * 取消aluop的中间信号连接main_decode 和 alu_dec
 * 直接使用[5:0]funct + [5:0]op来判断[7:0] alucontrol
*/
module alu_dec(
	input wire [5:0] funct,
	// input wire [1:0] aluop,
    input wire [5:0] op,
    input wire [4:0] rs,
    input wire [4:0] rt,
	output reg [7:0] alucontrol
    );

    // wire [2:0] func_tran;

    // assign alucontrol = (aluop == 2'b00) ? 3'b010 : // add lw/sw
    //                     (aluop == 2'b01) ? 3'b110 : // sub beq 
    //                     (aluop == 2'b10) ? func_tran : // up to funct R-type
    //                     3'b100; // wrong
    
    // assign func_tran = (funct == 6'b100000) ? 3'b010 : // add Add
    //                    (funct == 6'b100010) ? 3'b110 : // sub Sub
    //                    (funct == 6'b100100) ? 3'b000 : // and And
    //                    (funct == 6'b100101) ? 3'b001 : // or Or
    //                    (funct == 6'b101010) ? 3'b111 : // slt SLT
    //                    3'b000; // wrong

    always @(*) begin
        case (op)
            // R-type
            `EXE_NOP : case (funct)
                //logic inst
                `EXE_AND    :alucontrol <= `EXE_AND_OP      ;
                `EXE_OR     :alucontrol <= `EXE_OR_OP       ;
                `EXE_XOR    :alucontrol <= `EXE_XOR_OP      ;
                `EXE_NOR    :alucontrol <= `EXE_NOR_OP      ;
                //shift inst
                `EXE_SLL    :alucontrol <= `EXE_SLL_OP      ;
                `EXE_SLLV   :alucontrol <= `EXE_SLLV_OP     ;
                `EXE_SRL    :alucontrol <= `EXE_SRL_OP      ;
                `EXE_SRLV   :alucontrol <= `EXE_SRLV_OP     ;
                `EXE_SRA    :alucontrol <= `EXE_SRA_OP      ;
                `EXE_SRAV   :alucontrol <= `EXE_SRAV_OP     ;
                //move inst
                `EXE_MFHI   :alucontrol <= `EXE_MFHI_OP     ;
                `EXE_MTHI   :alucontrol <= `EXE_MTHI_OP     ;
                `EXE_MFLO   :alucontrol <= `EXE_MFLO_OP     ;
                `EXE_MTLO   :alucontrol <= `EXE_MTLO_OP     ;
                // Arithmetic inst
                `EXE_ADD    :alucontrol <= `EXE_ADD_OP      ;
                `EXE_ADDU   :alucontrol <= `EXE_ADDU_OP     ;
                `EXE_SUB    :alucontrol <= `EXE_SUB_OP      ;
                `EXE_SUBU   :alucontrol <= `EXE_SUBU_OP     ;
                `EXE_SLT    :alucontrol <= `EXE_SLT_OP      ;
                `EXE_SLTU   :alucontrol <= `EXE_SLTU_OP     ;
                `EXE_MULT   :alucontrol <= `EXE_MULT_OP     ;
                `EXE_MULTU  :alucontrol <= `EXE_MULTU_OP    ;
                `EXE_DIV    :alucontrol <= `EXE_DIV_OP      ;
                `EXE_DIVU   :alucontrol <= `EXE_DIVU_OP     ;
                //J type
                `EXE_JR     :alucontrol <= `EXE_J_OP        ;
                `EXE_JALR   :alucontrol <= `EXE_JALR_OP     ;
                // sink in inst
                `EXE_BREAK  :alucontrol <= `EXE_BREAK_OP    ;
                `EXE_SYSCALL:alucontrol <= `EXE_SYSCALL_OP  ;
                default     :alucontrol <= `EXE_NOP_OP      ;
            endcase
            //logic inst
            `EXE_ANDI   :alucontrol <= `EXE_ANDI_OP     ;
            `EXE_XORI   :alucontrol <= `EXE_XORI_OP     ;
            `EXE_LUI    :alucontrol <= `EXE_LUI_OP      ;
            `EXE_ORI    :alucontrol <= `EXE_ORI_OP      ;
            // Arithmetic inst
            `EXE_ADDI   :alucontrol <= `EXE_ADDI_OP     ;
            `EXE_ADDIU  :alucontrol <= `EXE_ADDIU_OP    ;
            `EXE_SLTI   :alucontrol <= `EXE_SLTI_OP     ;
            `EXE_SLTIU  :alucontrol <= `EXE_SLTIU_OP    ;
            //J type
            `EXE_J      :alucontrol <= `EXE_J_OP        ;
            `EXE_JAL    :alucontrol <= `EXE_JAL_OP      ;
            // 还有两条j指令在rtype里面
            `EXE_BEQ    :alucontrol <= `EXE_BEQ_OP      ;
            `EXE_BGTZ   :alucontrol <= `EXE_BGTZ_OP     ;
            `EXE_BLEZ   :alucontrol <= `EXE_BLEZ_OP     ;
            `EXE_BNE    :alucontrol <= `EXE_BNE_OP      ;
            
            `EXE_REGIMM_INST: case(rt)
                `EXE_BLTZ   :alucontrol <= `EXE_BLTZ_OP     ;
                `EXE_BLTZAL :alucontrol <= `EXE_BLTZAL_OP   ;
                `EXE_BGEZ   :alucontrol <= `EXE_BGEZ_OP     ;
                `EXE_BGEZAL :alucontrol <= `EXE_BGEZAL_OP   ;
                default     :alucontrol <= `EXE_NOP_OP      ;
            endcase
            // memory insts
            `EXE_LB     :alucontrol <= `EXE_LB_OP   ;
            `EXE_LBU    :alucontrol <= `EXE_LBU_OP  ;
            `EXE_LH     :alucontrol <= `EXE_LH_OP   ;
            `EXE_LHU    :alucontrol <= `EXE_LHU_OP  ;
            `EXE_LW     :alucontrol <= `EXE_LW_OP   ;
            `EXE_SB     :alucontrol <= `EXE_SB_OP   ;
            `EXE_SH     :alucontrol <= `EXE_SH_OP   ;
            `EXE_SW     :alucontrol <= `EXE_SW_OP   ;
            // privileged inst
            // 此处特权指令全部都直接alu nop
            // 后续添加特权指令再进行审核与修改
            6'b010000 : case (rs)
                5'b00100 :  alucontrol   <= `EXE_MTC0_OP;
                5'b00000 :  alucontrol   <= `EXE_MFC0_OP;
                5'b00001 :  alucontrol   <= `EXE_ERET_OP;
                default:    alucontrol   <= `EXE_NOP_OP ;
            endcase
             
            default : alucontrol    <= `EXE_NOP_OP  ;
        endcase
    end

endmodule
