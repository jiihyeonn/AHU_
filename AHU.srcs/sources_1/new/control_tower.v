`timescale 1ns / 1ps

module control_tower(
    input clk,
    input reset,
    input btnL,

    input [7:0] hum_int,
    input [7:0] hum_dec,
    input [7:0] tem_int,
    input [7:0] tem_dec,

    input [7:0] rtc_sec,
    input [7:0] rtc_min,
    input [7:0] rtc_hour,
    input [7:0] rtc_date,
    input [7:0] rtc_month,
    input [7:0] rtc_year,

    input sw0,
    input [7:0] alarm_hour, 
    input [7:0] alarm_min, 

    output reg [13:0] fnd_data
);

    reg r_display_mode; // 0: 온습도 화면, 1: 시간 화면
    reg r_prev;

    // 모드 전환
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            r_display_mode <= 1'b0;
            r_prev <= 1'b0;
        end else begin
            if (btnL == 1'b1 && r_prev == 1'b0) begin
                r_display_mode <= ~r_display_mode;
            end
            r_prev <= btnL;
        end
    end

    always @(*) begin
        if (r_display_mode == 1'b0) begin
            //  온습도 모드
            fnd_data = (tem_int * 100) + hum_int;
        end else begin
            // 시계 모드
            if (sw0 == 1'b1) begin
                // 알람 설정 모드 - sw on 
                fnd_data = (alarm_hour * 100) + alarm_min;
            end else begin
                // 일반 시계 모드 - sw off
                fnd_data = (rtc_hour * 100) + rtc_min; 
            end
        end
    end

endmodule