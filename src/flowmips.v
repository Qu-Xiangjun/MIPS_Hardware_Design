module flowmips(
	input wire clk,rst,
    input wire[5:0] int,
    output inst_sram_en,
	output wire[31:0] pc,
	input wire[31:0] instr,
	output wire memwriteM,
	output wire[31:0] aluoutM,WriteDataM,
	input wire[31:0] readdata,
    output wire [3:0] selM, // 写存储的字节选择

    output wire longest_stall, // 全局stall指令
    input wire i_stall,       // 两个访存 stall信号
    input wire d_stall,

    output wire [31:0]  debug_wb_pc,      
    output wire [3:0]   debug_wb_rf_wen,
    output wire [4:0]   debug_wb_rf_wnum, 
    output wire [31:0]  debug_wb_rf_wdata
    );

    // 将datapath和controller直接合并起来
    wire [31:0] pc_in,pc_add4F,pc_add4D,pc_add4E,inst_ce,pc_temp1,pc_temp2,pc_temp3,pc_temp4,pc_temp5;
	wire [31:0] after_shift;
	wire [31:0] SrcAD,SrcAE,SrcBE,defaultSrcAE;
	wire [31:0]	SignImmD,SignImmE;
    wire [31:0] pc_branchD, pc_branchE;
    wire [31:0] ra;
	wire[31:0] instrD,aluoutE;
    wire [7:0] alucontrolD,alucontrolE,alucontrolM,alucontrolW;
    wire branchD,branchE,branchM,jumpD,memtoregD,memwriteD,alusrcD,regdstD,regwriteD;
    wire jumprD;
    wire regwriteE,memtoregE,memwriteE,alusrcE,regdstE;
    wire regwriteM,memtoregM;
    wire regwriteW,zeroE,memtoregW;
    wire [4:0] WriteRegTemp,WriteRegE,WriteRegM,WriteRegW;
	wire [31:0] ResultW,writedataD,WriteDataE,defaultWriteDataE,handled_WriteDataE,readdataW,handled_readdataW,aluoutW;
    wire [4:0] rsD,rsE,rtD,RtE,RdE,rdD,saD,saE,RdM;
    wire [3:0] selE;

    // stall信号太乱 统一接口到hazard中
    wire stallF,stallD,stallE,stallM,stallW;
    wire flushF,flushD,flushE,flushM,flushW; 
    
    wire [31:0] eq1,eq2;
    wire [1:0] forwardAE,forwardBE;
    wire forwardAD,forwardBD;
	wire forwardcp0dataE;

    wire [31:0] pcF,pcD,pcE,pcM,pcW;

    // 针对al型指令的PC值 例如jal bltzal等
    wire [4:0] pc_al_dst;
    assign pc_al_dst = 5'b11111;
    wire write_alD,write_alE;

    wire overflowE; // 溢出信号
    wire div_stall; // div运算stallE信号
    wire laddressError;  // 读地址错误例外
    wire saddressError;  // 写地址错误例外
    wire [7:0] exceptF,exceptD,exceptE,exceptM;
	wire is_in_delayslotF,is_in_delayslotD,is_in_delayslotE,is_in_delayslotM;//CP0 delaysolt  
    wire invalidD;
    wire [31:0] exceptiontypeM;
    wire cp0writeD,cp0writeE,cp0writeM;
    wire exceptionoccur;
	wire [31:0] cp0dataoutE;
	wire [31:0] statusout;
	wire [31:0] causeout;
	wire [31:0] epcout;
    wire [31:0] pcexceptionM;
    wire [31:0] cp0aluin;  // mfc0的输入

    wire [39:0] ascii;

    // 预测模块
    wire predictF,predictD, predictE, predict_wrong,predict_wrongM;
    wire actual_takeM, actual_takeE;
    // assign predictD = 1'b1;
    // assign predictD = 1'b0;
    assign predict_wrong = (predictE != zeroE);

	// flopr 1
    mux2 #(32) before_pc_which_wrong(pc_temp1,pc_branchE,pc_add4E+4, predictE);
    mux2 #(32) before_pc_wrong(pc_temp2,pc_add4F,pc_branchD, branchD & predictD);
    mux2 #(32) before_pc_predict(pc_temp3,pc_temp2,pc_temp1,predict_wrong & branchE);
    mux2 #(32) before_pc_jump(pc_temp4,pc_temp3,{pc_add4D[31:28],instrD[25:0],2'b00},jumpD);
    mux2 #(32) before_pc_jumpr(pc_temp5,pc_temp4,eq1,jumprD);   // TODO 注意这里可能有数据冒险 eq1是数据前推
	mux2 #(32) before_pc_exception(pc_in,pc_temp5,pcexceptionM,exceptionoccur);

    instdec my_instdec(instr,ascii); // instr ascii转换
	
    // assign inst_sram_en = 1'b1;
    reg pre_inst_sram_en;
    assign inst_sram_en = pre_inst_sram_en & ~exceptionoccur;
    // assign inst_sram_en = pre_inst_sram_en;
    always @(negedge clk) begin
        if(rst) begin
            pre_inst_sram_en <= 0;
        end
        else begin
            pre_inst_sram_en <= 1;
        end
    end

    pc my_pc(clk,rst,~stallF,pc_in,pc,inst_ce); 
	adder my_adder_pc(inst_ce,32'b100,pc_add4F);
    assign pcF = pc;

    //TODO: pc地址错误,syscallD,breakD,eretD,invalidD,overflowE,laddressError,saddressError
    assign exceptF = (pcF[1:0] == 2'b00) ? 8'b00000000 : 8'b10000000;//the addr error
	assign is_in_delayslotF = (jumpD|jumprD|branchD);

    // 前一条为branch 且 预测错误，则需要flushD
    // 若当前预测要跳, 则flushD
    // assign flushD = (branchE & predict_wrong);// | (predictD & branchD);
    // ! 修复分支预测模块忽略延迟槽的问题
    // ! 已移植flushD到hazard
	// flopr 2
    // TODO: 若有延迟槽，则这里不能flush
	flopenrc #(32) fp2_1(clk, rst, ~stallD , flushD,instr,instrD);
	flopenrc #(32) fp2_2(clk, rst, ~stallD , flushD,pc_add4F,pc_add4D);
    flopenrc #(32) fp2_3(clk, rst, ~stallD , flushD, pcF, pcD);
    flopenrc #(8)  fp2_4(clk, rst, ~stallD , flushD,exceptF,exceptD);
	flopenrc #(1)  fp2_5(clk, rst, ~stallD , flushD,is_in_delayslotF,is_in_delayslotD);

    controller c(instrD[31:26],instrD[5:0],rsD,rtD,memtoregD,
	memwriteD,branchD,alusrcD,regdstD,regwriteD,write_alD,jumpD,
    jumprD,alucontrolD,invalidD,cp0writeD);

	signext my_sign_extend(instrD[15:0],SignImmD);
	regfile my_register_file(clk,regwriteW,instrD[25:21],instrD[20:16],WriteRegW,ResultW,SrcAD,writedataD,ra);
    // regfile(i clk,i we3,i w[4:0] ra1,ra2,wa3, i w[31:0] wd3,o w[31:0] rd1,rd2);
    sl2 my_shift_left(SignImmD,after_shift);

	adder my_adder_branch(after_shift,pc_add4D,pc_branchD);

    // 分支预判 + 数据前推 注意这里是预判不是预测

    mux2 #(32) forward1_1(eq1,SrcAD,aluoutM,forwardAD);
    mux2 #(32) forward1_2(eq2,writedataD,aluoutM,forwardBD);

    // 异常判断
    assign syscallD = (instrD[31:26] == 6'b000000 && instrD[5:0] == 6'b001100);
	assign breakD = (instrD[31:26] == 6'b000000 && instrD[5:0] == 6'b001101);
	assign eretD = (instrD == 32'b01000010000000000000000000011000);


    // wire flush_endE;
    // assign flush_endE = flushE;// | (predict_wrong & branchE);
    // ! 修复分支预测模块忽略延迟槽的问题

    // flopr 3
    flopenrc #(13)  fp3_1(clk, rst, ~stallE, flushE, {regwriteD,memtoregD,memwriteD,alucontrolD,alusrcD,regdstD},{regwriteE,memtoregE,memwriteE,alucontrolE,alusrcE,regdstE});
    flopenrc #(32)  fp3_2(clk, rst, ~stallE, flushE, SrcAD,defaultSrcAE);
    flopenrc #(32)  fp3_3(clk, rst, ~stallE, flushE, writedataD,defaultWriteDataE);
    flopenrc #(5)   fp3_4(clk, rst, ~stallE, flushE, rsD,rsE);
    flopenrc #(5)   fp3_5(clk, rst, ~stallE, flushE, rtD,RtE);
    flopenrc #(5)   fp3_6(clk, rst, ~stallE, flushE, rdD,RdE);
    flopenrc #(32)  fp3_7(clk, rst, ~stallE, flushE, SignImmD,SignImmE);
    flopenrc #(32)  fp3_8(clk, rst, ~stallE, 1'b0  , pc_add4D,pc_add4E); // 不受flush影响 TODO: 分支预测 模块 有可能不要flush
    flopenrc #(1)   fp3_9(clk, rst, ~stallE, flushE, pcsrcD,pcsrcE);
    flopenrc #(32) fp3_10(clk, rst, ~stallE, flushE, pc_branchD,pc_branchE);
    flopenrc #(1)  fp3_11(clk, rst, ~stallE, flushE, EqualD, EqualE);
    flopenrc #(1)  fp3_12(clk, rst, ~stallE, flushE, predictD, predictE);
    flopenrc #(1)  fp3_13(clk, rst, ~stallE, flushE, branchD, branchE);
    flopenrc #(32) fp3_14(clk, rst, ~stallE, flushE, pcD, pcE);
    flopenrc #(5)  fp3_15(clk, rst, ~stallE, flushE, saD, saE);
    flopenrc #(1)  fp3_16(clk, rst, ~stallE, 1'b0  , write_alD, write_alE); // 不受flush影响
	flopenrc #(8)  fp3_17(clk, rst, ~stallE, flushE, {exceptD[7],syscallD,breakD,eretD,invalidD,exceptD[2:0]},exceptE);
    flopenrc #(1)  fp3_18(clk, rst, ~stallE, flushE, is_in_delayslotD, is_in_delayslotE); // 不受flush影响
    flopenrc #(1)  fp3_19(clk, rst, ~stallE, flushE, cp0writeD, cp0writeE);


    // 信号数据
    assign rsD = instrD[25:21];
    assign rtD = instrD[20:16];
    assign rdD = instrD[15:11];
    assign saD = instrD[10:6];

    // 是否真的跳转
    assign actual_takeE = zeroE;


    wire [63:0] hilo_o; // 软替代hiloreg

    // 数据前推补充
    mux3 #(32) forward2_1(SrcAE,defaultSrcAE,ResultW,aluoutM,forwardAE);
    mux3 #(32) forward2_2(WriteDataE,defaultWriteDataE,ResultW,aluoutM,forwardBE);

    mux2 #(5) after_regfile(WriteRegTemp,RtE,RdE,regdstE);

    // 处理al型指令的选择
    mux2 #(5) mux_for_al(WriteRegE,WriteRegTemp,pc_al_dst,write_alE);

	mux2 #(32) before_alu(SrcBE,WriteDataE,SignImmE,alusrcE);


    mux2 #(32) forwardcp0datamux (cp0aluin,cp0dataoutE,aluoutM,forwardcp0dataE);


    alu my_alu(clk,rst,SrcAE,SrcBE,saE,alucontrolE,hilo_o[63:32],hilo_o[31:0], flushE,1'b0,
                pc_add4E,cp0aluin,exceptionoccur,aluoutE,hilo_o,overflowE,zeroE,div_stall,laddressError,saddressError);

    // 处理写入SH、SB
    WriteData_handle my_WriteData_handle(alucontrolE,aluoutE,WriteDataE,selE,handled_WriteDataE);

    // flopr 4
    flopenrc #(3)  fp4_1(clk,  rst, ~stallM, flushM, {regwriteE,memtoregE,memwriteE},{regwriteM,memtoregM,memwriteM});
    flopenrc #(32) fp4_2(clk,  rst, ~stallM, flushM, aluoutE,aluoutM);
    flopenrc #(32) fp4_3(clk,  rst, ~stallM, flushM, handled_WriteDataE,WriteDataM);
    flopenrc #(5)  fp4_4(clk,  rst, ~stallM, flushM, WriteRegE,WriteRegM);
    // flopr #(32) fp4_5(clk,  rst, ~stallM, flushM, pc_branchE,pc_branchM);
    flopenrc #(1)  fp4_6(clk,  rst, ~stallM, flushM,  branchE, branchM);
    flopenrc #(32) fp4_7(clk,  rst, ~stallM, flushM, pcE,pcM);
    flopenrc #(1)  fp4_8(clk,  rst, ~stallM, flushM,  actual_takeE, actual_takeM);
    flopenrc #(1)  fp4_9(clk,  rst, ~stallM, flushM,  predict_wrong,predict_wrongM);
    flopenrc #(4)  fp4_10(clk, rst, ~stallM, flushM,  selE,selM);
    flopenrc #(8)  fp4_11(clk, rst, ~stallM, flushM,  alucontrolE,alucontrolM);
    flopenrc #(8)  fp4_12(clk, rst, ~stallM, flushM, {exceptE[7:3],overflowE,laddressError,saddressError},exceptM);
    flopenrc #(1)  fp4_13(clk, rst, ~stallM, flushM,  is_in_delayslotE,is_in_delayslotM);
    flopenrc #(5)  fp4_14(clk, rst, ~stallM, flushM, RdE,RdM);
    flopenrc #(1)  fp4_15(clk, rst, ~stallM, flushM, cp0writeE,cp0writeM);

    wire [31:0] real_causeout,real_pcM;
    reg [31:0] cause_o;

    always@(*) begin
        if(rst) cause_o = 32'b0;
        else begin
            cause_o[9:8] = aluoutM[9:8];
	        cause_o[23] = aluoutM[23];
	        cause_o[22] = aluoutM[22];
        end
    end

    // assign cause_o[9:8] = aluoutM[9:8];
	// assign cause_o[23] = aluoutM[23];
	// assign cause_o[22] = aluoutM[22];

    assign real_causeout = (RdM == 5'b01101 && cp0writeM) ? cause_o:causeout;
    assign real_pcM = (RdM == 5'b01101 && cp0writeM) ? pcE : pcM;

    // 异常处理模块
    exceptiondec exceptiondec (rst,exceptM,exceptM[1],exceptM[0],statusout,
                real_causeout,epcout, exceptionoccur,exceptiontypeM,pcexceptionM);
    
    wire [31:0]countout,compareout,configout,pridout,badvaddrout,bad_addr;
    wire timerintout;
    assign bad_addr = (exceptM[7])? pcM : aluoutM; // pc错误时，bad_addr_i为pcM，否则为计算出来的load store地址
    cp0_reg cp0 (
        // input
		.clk 				(clk 			    ),
		.rst 				(rst 			    ),
		.we_i 				(cp0writeM 		    ),  // 写cp0，maindec中判断
		.waddr_i 			(RdM 			    ),
		.raddr_i 			(RdE 			    ),
		.data_i 			(aluoutM 		    ),
		.int_i 				(int 			    ),
		.excepttype_i 		(exceptiontypeM	    ),
		.current_inst_addr_i(real_pcM 			),
		.is_in_delayslot_i	(is_in_delayslotM   ),
		.bad_addr_i			(bad_addr		    ), // 出错的虚地址（load store)均为alu计算出的结果
        // output
		.data_o				(cp0dataoutE 	    ),
		.count_o			(countout 	),//	    
		.compare_o			(compareout ),//	    
        
		.status_o			(statusout 		    ),    	
		.cause_o			(causeout 		    ),
		.epc_o				(epcout 		    ),

		.config_o			(configout 		),//    
		.prid_o				(pridout 		),//    
		.badvaddr			(badvaddrout 	),//    
		.timer_int_o		(timerintout	)//    
	);



    // cp0
    
    // hilo_reg hilo_at4(clk,rst,we,hi,lo,hi_o,lo_o);

    // flopr 5
    flopenrc #(2)  fp5_1(clk, rst, ~stallW, flushW, {regwriteM,memtoregM},{regwriteW,memtoregW});
	flopenrc #(32) fp5_2(clk, rst, ~stallW, flushW, aluoutM,aluoutW);
    flopenrc #(32) fp5_3(clk, rst, ~stallW, flushW, readdata,readdataW);
    flopenrc #(5)  fp5_4(clk, rst, ~stallW, flushW, WriteRegM,WriteRegW);
    flopenrc #(8)  fp5_5(clk, rst, ~stallW, flushW, alucontrolM,alucontrolW);
    flopenrc #(32) fp5_6(clk, rst, ~stallW, flushW, pcM,pcW);
    

    // 处理lh lhu lbu lb lw
    ReadData_handle my_ReadData_handle(alucontrolW,readdataW,aluoutW,handled_readdataW);

    mux2 #(32) afer_data_mem(ResultW,aluoutW,handled_readdataW,memtoregW);

    hazard my_hazard_unit(rsD, rtD, rsE, RtE, RdE, RdM, WriteRegE, WriteRegM, WriteRegW,
    regwriteE, regwriteM, regwriteW, memtoregD, memtoregE,memtoregM, branchD, jumprD,cp0writeM,
    exceptionoccur,div_stall,i_stall,d_stall,branchE,predict_wrong,
    forwardAE, forwardBE, forwardAD, forwardBD, forwardcp0dataE,
    stallF, stallD, stallE, stallM, stallW,
    flushF, flushD, flushE, flushM, flushW,
    longest_stall);

    compete_predict branch_predict(clk, rst, flushD, stallD, pcF, pcM,
    branchD, branchM, actual_takeM, actual_takeE,
    predict_wrongM, predictD, predictF);
   


    // DEBUG OUTPUT
    assign debug_wb_pc          = pcW;
    assign debug_wb_rf_wen      = {4{regwriteW & ~stallW}};
    assign debug_wb_rf_wnum     = WriteRegW;
    assign debug_wb_rf_wdata    = ResultW;

endmodule