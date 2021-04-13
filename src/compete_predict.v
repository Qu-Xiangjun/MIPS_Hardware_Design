module compete_predict (
    input wire clk, rst,
    
    input wire flushD,
    input wire stallD,

    input wire [31:0] pcF, pcM,

    input wire branchD,
    input wire branchM,         // M阶段是否是分支指令
    input wire actual_takeM,    // 实际是否跳
    input wire actual_takeE,
    input wire pred_wrong, // 预测结果是否正确，memory阶段需要
    output wire pred_takeD,
    output wire pred_takeF
);
    reg pred_takeF_r;

    wire pred_takeD_local, pred_takeD_global;
    wire pred_takeF_local, pred_takeF_global;
    wire pred_wrongM_local, pred_wrongM_global;

    branch_predict_local mybpl(
        .clk(clk), 
        .rst(rst),
        .flushD(flushD),
        .stallD(stallD),
        .pcF(pcF), 
        .pcM(pcM),
        .branchD(branchD),
        .branchM(branchM),         // M阶段是否是分支指令
        .actual_takeM(actual_takeM),    // 实际是否跳转
        .actual_takeE(actual_takeE),
        .pred_wrong(pred_wrong),
        .pred_takeD(pred_takeD_local),
        .pred_takeF(pred_takeF_local)
        );

    branch_predict_global mybpg(
        .clk(clk), 
        .rst(rst),
        .flushD(flushD),
        .stallD(stallD),
        .pcF(pcF), 
        .pcM(pcM),
        .branchD(branchD),
        .branchM(branchM),         // M阶段是否是分支指令
        .actual_takeM(actual_takeM),    // 实际是否跳转
        .actual_takeE(actual_takeE),
        .pred_wrong(pred_wrong),
        .pred_takeD(pred_takeD_global),
        .pred_takeF(pred_takeF_global)
        );

// 定义参数
    // parameter Strongly_not_taken = 2'b00, Weakly_not_taken = 2'b01, Weakly_taken = 2'b11, Strongly_taken = 2'b10;
    parameter Strongly_local = 2'b00, Weakly_local = 2'b01, Weakly_global = 2'b10, Strongly_global = 2'b11;
    parameter CPHT_DEPTH = 6;

// 

    reg [1:0] CPHT [(1<<CPHT_DEPTH)-1:0];
    
    integer i,j;
    

// ---------------------------------------预测逻辑---------------------------------------
    wire [(CPHT_DEPTH-1):0] index1, index2, CPHT_index;

    assign index1 = pcF[7:2];     
    assign index2 = pcF[13:8];
    assign CPHT_index = index2 ^ index1;

    assign CPHT_value = CPHT[CPHT_index][1];      // 在取指阶段预测是否会跳转，并经过流水线传递给译码阶段。

    assign pred_takeF = CPHT_value ? pred_takeF_global : pred_takeF_local;


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

// ---------------------------------------预测逻辑---------------------------------------


// ---------------------------------------CPHT初始化以及更新---------------------------------------
    wire [(CPHT_DEPTH-1):0] update_index1;
    wire [(CPHT_DEPTH-1):0] update_index2;
    wire [(CPHT_DEPTH-1):0] update_CPHT_index;

    assign update_index1 = pcM[7:2];     
    assign update_index2 = pcM[13:8];  
    assign update_CPHT_index = update_index2 ^ update_index1;

    assign pred_wrongM_local = (pred_takeF_local != actual_takeE);
    assign pred_wrongM_global = (pred_takeF_global != actual_takeE);

    always @(posedge clk) begin
        if(rst) begin
            for(i = 0; i < (1<<CPHT_DEPTH); i=i+1) begin
                CPHT[i] <= Weakly_global;
            end
        end
        else if (branchM) begin
            case(CPHT[update_CPHT_index])
                // 此处应该添加你的更新逻辑的代码
                Strongly_local: begin
                    if(pred_wrongM_local && !pred_wrongM_global) begin
                        CPHT[update_CPHT_index] <= Weakly_local;
                    end

                    else begin
                        CPHT[update_CPHT_index] <= CPHT[update_CPHT_index];
                    end
                end

                Weakly_local: begin
                    if(!pred_wrongM_local && pred_wrongM_global) begin
                        CPHT[update_CPHT_index] <= Strongly_local;
                    end

                    else begin
                        if(pred_wrongM_local && !pred_wrongM_global) begin
                            CPHT[update_CPHT_index] <= Weakly_global;
                        end
                        else begin
                            CPHT[update_CPHT_index] <= CPHT[update_CPHT_index];
                        end
                    end
                end

                Weakly_global: begin
                    if(!pred_wrongM_local && pred_wrongM_global) begin
                        CPHT[update_CPHT_index] <= Weakly_local;
                    end

                    else begin
                        if(pred_wrongM_local && !pred_wrongM_global) begin
                            CPHT[update_CPHT_index] <= Strongly_global;
                        end
                        else begin
                            CPHT[update_CPHT_index] <= CPHT[update_CPHT_index];
                        end
                    end
                end

                Strongly_global: begin
                    if(!pred_wrongM_local && pred_wrongM_global) begin
                        CPHT[update_CPHT_index] <= Weakly_global;
                    end

                    else begin
                        CPHT[update_CPHT_index] <= CPHT[update_CPHT_index];
                    end
                end

                default:
                    CPHT[update_CPHT_index] <= Weakly_global;
            endcase 
        end
    end
// ---------------------------------------PHT初始化以及更新---------------------------------------

    // 译码阶段输出最终的预测结果
    assign pred_takeD = branchD & pred_takeF_r;  
endmodule
