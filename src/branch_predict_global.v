module branch_predict_global (
    input wire clk, rst,
    
    input wire flushD,
    input wire stallD,

    input wire [31:0] pcF, pcM,

    input wire branchD,
    input wire branchM,         // M阶段是否是分支指令
    input wire actual_takeM,    // 实际是否跳转
    input wire actual_takeE,
    input wire pred_wrong, // 预测结果是否正确，memory阶段需要
    output wire pred_takeD,      // 预测是否跳转
    output wire pred_takeF
);

    // wire pred_takeF;   //预测
    reg pred_takeF_r; //把结果存下来

// 定义参数
    parameter Strongly_not_taken = 2'b00, Weakly_not_taken = 2'b01, Weakly_taken = 2'b11, Strongly_taken = 2'b10;
    parameter GHR_LENGTH = 8;

    reg [GHR_LENGTH-1:0] GHR_value;
    reg [GHR_LENGTH-1:0] GHR_value_old;

    reg [GHR_LENGTH-1:0] GHR_value_old_D;
    reg [GHR_LENGTH-1:0] GHR_value_old_E;
    reg [GHR_LENGTH-1:0] GHR_value_old_M;

    reg [1:0] PHT [(1<<GHR_LENGTH)-1:0];
    integer i,j;

    wire [(GHR_LENGTH-1):0] PHT_index;

// ---------------------------------------预测逻辑，Fetch阶段---------------------------------------

    assign PHT_index = pcF[9:2] ^ GHR_value; // 使用XOR避免冲突


    assign pred_takeF = PHT[PHT_index][1];      // 在取指阶段预测是否会跳转，并经过流水线传递给译码阶段。

        // --------------------------pipeline------------------------------
            always @(posedge clk) begin
                if(rst | flushD) begin
                    pred_takeF_r <= 0;
                end
                else if(~stallD) begin
                    pred_takeF_r <= pred_takeF;
                end
            end
        // --------------------------pipeline------------------------------

// ---------------------------------------预测逻辑结束---------------------------------------

// ---------------------------------------BHT初始化以及更新，Memory阶段---------------------------------------
    wire [(GHR_LENGTH-1):0] update_PHT_index;


    always@(posedge clk) begin
        if(rst) begin
            GHR_value <= 0; 
            GHR_value_old <= 0; // 为了在fetch阶段得到ghr的值
        end
        else if(!stallD & branchD) begin // 这条指令是branch且没有被阻塞就可以更新ghr值，是decode阶段
            GHR_value_old <= GHR_value;
            GHR_value <= {GHR_value << 1, pred_takeD};
            
        end else if(pred_wrong && branchM) begin // 得到预测检查结果后，如果预测是错的(memory 阶段)
            GHR_value <= {GHR_value_old <<1, actual_takeM};
            GHR_value_old <= GHR_value;
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            GHR_value_old_D <= 0;
            GHR_value_old_E <= 0;
            GHR_value_old_M <= 0;
        end
        else begin
            GHR_value_old_D <= GHR_value_old;
            GHR_value_old_E <= GHR_value_old_D;
            GHR_value_old_M <= GHR_value_old_E;
        end
    end

// ---------------------------------------BHT初始化以及更新结束

    assign update_PHT_index = GHR_value_old_M ^ pcM[9:2];
// ---------------------------------------PHT初始化以及更新---------------------------------------
    always @(posedge clk) begin
        if(rst) begin
            for(i = 0; i < (1<<GHR_LENGTH); i=i+1) begin
                PHT[i] <= Weakly_taken;
            end
        end
        else if(branchM) begin
            case(PHT[update_PHT_index])
                // 此处应该添加你的更新逻辑的代码
                Strongly_not_taken: begin
                    if(actual_takeM) begin
                        PHT[update_PHT_index] <= Weakly_not_taken;
                    end

                    else begin
                        PHT[update_PHT_index] <= PHT[update_PHT_index];
                    end
                end

                Weakly_not_taken: begin
                    if(actual_takeM) begin
                        PHT[update_PHT_index] <= Weakly_taken;
                    end

                    else begin
                        PHT[update_PHT_index] <= Strongly_not_taken;
                    end
                end

                Weakly_taken: begin
                    if(actual_takeM) begin
                        PHT[update_PHT_index] <= Strongly_taken;
                    end

                    else begin
                        PHT[update_PHT_index] <= Weakly_not_taken;
                    end
                end

                Strongly_taken: begin
                    if(actual_takeM) begin
                        PHT[update_PHT_index] <= PHT[update_PHT_index];
                    end

                    else begin
                        PHT[update_PHT_index] <= Weakly_taken;
                    end
                end

            endcase 
        end
    end
// ---------------------------------------PHT初始化以及更新结束---------------------------------------

    // 译码阶段输出最终的预测结果
    assign pred_takeD = branchD & pred_takeF_r;  
endmodule