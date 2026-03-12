`timescale 1ns / 1ps

module alarm_controller(
    input clk,
    input reset,
    input sw0, 
    
    input cw_tick,
    input ccw_tick,
    input key_tick,
    
    // ds1302 시간
    input [7:0] current_hour,
    input [7:0] current_min,
    input [7:0] current_sec,
    
    // 알람 설정 시간
    output reg [7:0] alarm_hour,
    output reg [7:0] alarm_min,

    output reg led0,      
    output reg buzzer 
);

    localparam SET_HOUR = 2'd0;
    localparam SET_MIN  = 2'd1;
    localparam SET_DONE = 2'd2; 

    reg [1:0] set_state; // 위에 3개 상태
    reg is_armed; // 알람 울리는지 기억 플래그 (1: 알람 울리기 저장)
    reg r_alarm_ring; // 알람 울리는중: 1, 알람 안울림 : 0

    localparam DO = 22'd191_112; 
    localparam TIME_500MS = 26'd50_000_000; 
    
    reg [21:0] tone_cnt;
    reg [25:0] pattern_cnt;
    reg beep_en; 

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            tone_cnt <= 0; pattern_cnt <= 0; beep_en <= 0; buzzer <= 0;
        end else begin
            if (r_alarm_ring) begin
                if (pattern_cnt >= TIME_500MS - 1) begin
                    pattern_cnt <= 0; beep_en <= ~beep_en;
                end else pattern_cnt <= pattern_cnt + 1;
                
                if (beep_en) begin
                    if (tone_cnt >= DO - 1) begin
                        tone_cnt <= 0; buzzer <= ~buzzer; 
                    end else tone_cnt <= tone_cnt + 1;
                end else buzzer <= 0; 
            end else begin
                pattern_cnt <= 0; tone_cnt <= 0; beep_en <= 0; buzzer <= 0;
            end
        end
    end

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            alarm_hour <= 8'd0;
            alarm_min <= 8'd0;
            set_state <= SET_HOUR;
            is_armed <= 1'b0;
            led0 <= 1'b0;
            r_alarm_ring <= 1'b0;
        end else begin
            if (is_armed && !r_alarm_ring) begin
                if (sw0 && key_tick) begin
                    is_armed <= 1'b0;
                    led0 <= 1'b0;
                    set_state <= SET_HOUR;
                end
                
                else if ((current_hour == alarm_hour) && (current_min == alarm_min) && (current_sec == 8'd0)) begin
                        r_alarm_ring <= 1'b1; 
                        led0 <= 1'b0;
                        is_armed <= 1'b0; 
                end
            end
            
            // 알람이 울리고 있을 때
            else if (r_alarm_ring) begin
                // 부저가 울릴 때 sw 상태와 관계없이 로터리 key 누르면 해제
                if (key_tick) begin
                    r_alarm_ring <= 1'b0;
                    is_armed <= 1'b0;
                    led0 <= 1'b0;
                    set_state <= SET_HOUR; 
                end
            end
            
            // 알람 세팅 모드
            else begin
                if (sw0) begin
                    case (set_state)
                        SET_HOUR: begin
                            if (cw_tick)  alarm_hour <= (alarm_hour == 23) ? 0 : alarm_hour + 1; // 정방향은 증가
                            if (ccw_tick) alarm_hour <= (alarm_hour == 0) ? 23 : alarm_hour - 1; // 역방향은 감소
                            if (key_tick) set_state <= SET_MIN;
                        end
                        
                        SET_MIN: begin
                            if (cw_tick)  alarm_min <= (alarm_min == 59) ? 0 : alarm_min + 1;
                            if (ccw_tick) alarm_min <= (alarm_min == 0) ? 59 : alarm_min - 1;
                            if (key_tick) begin
                                set_state <= SET_DONE; 
                                is_armed <= 1'b1; 
                                led0 <= 1'b1;
                            end
                        end
                        
                        SET_DONE: begin
                        end
                    endcase
                end else begin
                    // 스위치가 내렸을때 다시 시간 세팅으로 돌아감
                    set_state <= SET_HOUR; 
                end
            end
        end
    end
endmodule