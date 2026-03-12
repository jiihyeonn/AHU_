`timescale 1ns / 1ps

module data_sender(
    input clk,
    input reset,
    input start_trigger,
    
    // 센서 및 시간 데이터 입력
    input [7:0] hum_int, tem_int,
    input [7:0] rtc_year, rtc_month, rtc_day, rtc_hour, rtc_min, rtc_sec,
    
    input tx_busy,
    input tx_done,
    output reg [7:0] tx_data,
    output reg tx_start
);

    // 숫자 -> ASCII 
    wire [7:0] hum_10 = (hum_int / 10) % 10 + 8'h30;
    wire [7:0] hum_1  = hum_int % 10 + 8'h30;
    wire [7:0] tem_10 = (tem_int / 10) % 10 + 8'h30;
    wire [7:0] tem_1  = tem_int % 10 + 8'h30;
    
    wire [7:0] yy_10 = (rtc_year / 10) % 10 + 8'h30;
    wire [7:0] yy_1  = rtc_year % 10 + 8'h30;
    wire [7:0] mm_10 = (rtc_month / 10) % 10 + 8'h30;
    wire [7:0] mm_1  = rtc_month % 10 + 8'h30;
    wire [7:0] dd_10 = (rtc_day / 10) % 10 + 8'h30;
    wire [7:0] dd_1  = rtc_day % 10 + 8'h30;
    wire [7:0] hh_10 = (rtc_hour / 10) % 10 + 8'h30;
    wire [7:0] hh_1  = rtc_hour % 10 + 8'h30;
    wire [7:0] mn_10 = (rtc_min / 10) % 10 + 8'h30;
    wire [7:0] mn_1  = rtc_min % 10 + 8'h30;
    wire [7:0] ss_10 = (rtc_sec / 10) % 10 + 8'h30;
    wire [7:0] ss_1  = rtc_sec % 10 + 8'h30;

    localparam IDLE = 2'b00;
    localparam SEND = 2'b01;
    localparam WAIT = 2'b10;

    reg [1:0] state;
    reg [4:0] byte_cnt;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= IDLE;
            tx_start <= 1'b0;
            tx_data <= 8'd0;
            byte_cnt <= 0;
        end else begin
            case (state)
                IDLE: begin
                    tx_start <= 1'b0;
                    byte_cnt <= 0;
                    if (start_trigger) state <= SEND;
                end
                
                SEND: begin
                    if (!tx_busy) begin
                        tx_start <= 1'b1;
                        
                        // 총 26바이트 전송 포맷 매핑
                        case(byte_cnt)
                            5'd0:  tx_data <= 8'h54; // T
                            5'd1:  tx_data <= 8'h3A; // :
                            5'd2:  tx_data <= tem_10; 
                            5'd3:  tx_data <= tem_1;
                            5'd4:  tx_data <= 8'h0D; // \r
                            5'd5:  tx_data <= 8'h0A; // \n
                            
                            5'd6:  tx_data <= 8'h48; // H
                            5'd7:  tx_data <= 8'h3A; // :
                            5'd8:  tx_data <= hum_10; 
                            5'd9:  tx_data <= hum_1; 
                            5'd10: tx_data <= 8'h0D; // \r
                            5'd11: tx_data <= 8'h0A; // \n
                            
                            5'd12: tx_data <= yy_10; // 년
                            5'd13: tx_data <= yy_1;
                            5'd14: tx_data <= mm_10; // 월
                            5'd15: tx_data <= mm_1;
                            5'd16: tx_data <= dd_10; // 일
                            5'd17: tx_data <= dd_1;
                            5'd18: tx_data <= hh_10; // 시
                            5'd19: tx_data <= hh_1;
                            5'd20: tx_data <= mn_10; // 분
                            5'd21: tx_data <= mn_1;
                            5'd22: tx_data <= ss_10; // 초
                            5'd23: tx_data <= ss_1;
                            5'd24: tx_data <= 8'h0D; // \r
                            5'd25: tx_data <= 8'h0A; // \n
                            default: tx_data <= 8'h20;
                        endcase
                        state <= WAIT;
                    end
                end
                
                WAIT: begin
                    tx_start <= 1'b0;
                    if (tx_done) begin
                        if (byte_cnt == 5'd25) state <= IDLE;
                        else begin
                            byte_cnt <= byte_cnt + 1;
                            state <= SEND;
                        end
                    end
                end
                default: state <= IDLE;
            endcase
        end
    end
endmodule