`timescale 1ns / 1ps

module rotary(
    input clk,
    input reset,
    input clean_s1,
    input clean_s2,
    input clean_key,
    
    output reg cw_tick,
    output reg ccw_tick,
    output reg key_tick
);

    reg [1:0] r_prev_state, r_current_state;
    
    reg r_prev_key;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            r_prev_state <= 2'b11;
            r_current_state <= 2'b11;
            r_prev_key <= 1'b0;
            cw_tick <= 1'b0;
            ccw_tick <= 1'b0;
            key_tick <= 1'b0;
        end else begin
            // 펄스는 1클럭만 유지하고 바로 끔
            cw_tick <= 1'b0;
            ccw_tick <= 1'b0;
            key_tick <= 1'b0;

            // 로터리 회전 감지 (상태 변화 분석)
            r_prev_state <= r_current_state;
            r_current_state <= {clean_s1, clean_s2};

            case ({r_prev_state, r_current_state})
                // 시계 방향
                4'b1101, 4'b0100, 4'b0010, 4'b1011 : cw_tick <= 1'b1;
                // 반시계 방향
                4'b1110, 4'b1000, 4'b0001, 4'b0111 : ccw_tick <= 1'b1;
            endcase

            // key 클릭 감지
            r_prev_key <= clean_key;
            if (!r_prev_key && clean_key) begin
                key_tick <= 1'b1;
            end
        end
    end
endmodule