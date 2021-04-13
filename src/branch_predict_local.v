module branch_predict_local (
    input wire clk, rst,
    
    input wire flushD,
    input wire stallD,

    input wire [31:0] pcF, pcM,

    input wire branchD,
    input wire branchM,         // M阶段是否是分支指令
    input wire actual_takeM,    // 实际是否跳转
    input wire actual_takeE,
    input wire pred_wrong,
    output wire pred_takeD,      // 预测是否跳转
    output wire pred_takeF
);

    reg pred_takeF_r; //把结果存下来
    // assign branchD = //判断译码阶段是否是分支指令

// 定义参数
    parameter Strongly_not_taken = 2'b00, Weakly_not_taken = 2'b01, Weakly_taken = 2'b11, Strongly_taken = 2'b10;
    parameter PHT_DEPTH = 6;
    parameter BHT_DEPTH = 10;

// 
    reg [5:0] BHT [(1<<BHT_DEPTH)-1:0];
    reg [1:0] PHT [(1<<PHT_DEPTH)-1:0];
    
    integer i,j;
    wire [(PHT_DEPTH-1):0] PHT_index;
    wire [(BHT_DEPTH-1):0] BHT_index;
    wire [(PHT_DEPTH-1):0] BHR_value;

// ---------------------------------------预测逻辑，Fetch阶段---------------------------------------

    assign BHT_index = pcF[11:2];     
    assign BHR_value = BHT[BHT_index];  
    assign PHT_index = BHR_value ^ pcF[7:2]; // 使用XOR避免冲突，后面同步
 
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
    wire [(PHT_DEPTH-1):0] update_PHT_index;
    wire [(BHT_DEPTH-1):0] update_BHT_index;
    wire [(PHT_DEPTH-1):0] update_BHR_value;

    assign update_BHT_index = pcM[11:2];     
    assign update_BHR_value = BHT[update_BHT_index];  
    assign update_PHT_index = update_BHR_value ^ pcM[7:2];

    always@(posedge clk) begin
        if(rst) begin
            for(j = 0; j < (1<<BHT_DEPTH); j=j+1) begin
                BHT[j] <= 0;
            end
        end
        else if(branchM) begin
            // 此处应该添加你的更新逻辑的代码
            BHT[update_BHT_index] <= {(BHT[update_BHT_index] << 1), actual_takeM};
        end
    end
// ---------------------------------------BHT初始化以及更新结束---------------------------------------


// ---------------------------------------PHT初始化以及更新---------------------------------------
    always @(posedge clk) begin
        if(rst) begin
            for(i = 0; i < (1<<PHT_DEPTH); i=i+1) begin
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