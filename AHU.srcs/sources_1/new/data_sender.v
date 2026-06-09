`timescale 1ns / 1ps

module data_sender(
    input clk,
    input reset,
    input start_trigger,

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

    input tx_busy,
    input tx_done,
    output reg [7:0] tx_data,
    output reg tx_start
);
    function [7:0] to_ascii_10;
        input [7:0] val;
        begin
            to_ascii_10 = (val / 10) % 10 + 8'h30;
        end
    endfunction

    function [7:0] to_ascii_1;
        input [7:0] val;
        begin
            to_ascii_1 = val % 10 + 8'h30;
        end
    endfunction

    // 숫자 -> ASCII 문자로 변환
    wire [7:0] hum_10       = to_ascii_10(hum_int);
    wire [7:0] hum_1        = to_ascii_1(hum_int);
    wire [7:0] hum_10_dec   = to_ascii_10(hum_dec);
    wire [7:0] hum_1_dec    = to_ascii_1(hum_dec);
    wire [7:0] tem_10       = to_ascii_10(tem_int);
    wire [7:0] tem_1        = to_ascii_1(tem_int);
    wire [7:0] tem_10_dec   = to_ascii_10(tem_dec);
    wire [7:0] tem_1_dec    = to_ascii_1(tem_dec);

    wire [7:0] year_10      = to_ascii_10(rtc_year);
    wire [7:0] year_1       = to_ascii_1(rtc_year);
    wire [7:0] month_10     = to_ascii_10(rtc_month);
    wire [7:0] month_1      = to_ascii_1(rtc_month);
    wire [7:0] date_10      = to_ascii_10(rtc_date);
    wire [7:0] date_1       = to_ascii_1(rtc_date);
    wire [7:0] hour_10      = to_ascii_10(rtc_hour);
    wire [7:0] hour_1       = to_ascii_1(rtc_hour);
    wire [7:0] min_10       = to_ascii_10(rtc_min);
    wire [7:0] min_1        = to_ascii_1(rtc_min);
    wire [7:0] sec_10       = to_ascii_10(rtc_sec);
    wire [7:0] sec_1        = to_ascii_1(rtc_sec);

    localparam IDLE = 2'b00;
    localparam SEND = 2'b01;
    localparam WAIT = 2'b10;

    reg [1:0] state;
    reg [4:0] byte_cnt;     // byte 개수
    reg print_mode;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= IDLE;
            tx_start <= 1'b0;
            tx_data <= 8'd0;
            byte_cnt <= 5'd0;
            print_mode <= 0;
        end else begin
            case (state)
                IDLE: begin
                    tx_start <= 1'b0;
                    byte_cnt <= 5'd0;
                    print_mode <= 0;
                    if (start_trigger) begin
                        state <= SEND;
                    end
                end
                
                SEND: begin
                    if (!tx_busy) begin
                        tx_start <= 1'b1;
                        if(!print_mode) begin
                            case(byte_cnt)
                                5'd0:  tx_data <= 8'h32; // 2
                                5'd1:  tx_data <= 8'h30; // 0
                                5'd2:  tx_data <= year_10; 
                                5'd3:  tx_data <= year_1;
                                5'd4:  tx_data <= 8'h2E; // .
                                5'd5:  tx_data <= month_10;
                                5'd6:  tx_data <= month_1;
                                5'd7:  tx_data <= 8'h2E; // .
                                5'd8:  tx_data <= date_10;
                                5'd9:  tx_data <= date_1;
                                5'd10:  tx_data <= 8'h2E; // .
                                5'd11:  tx_data <= hour_10;
                                5'd12:  tx_data <= hour_1;
                                5'd13:  tx_data <= 8'h2E; // .
                                5'd14:  tx_data <= min_10;
                                5'd15:  tx_data <= min_1;
                                5'd16:  tx_data <= 8'h2E; // .
                                5'd17:  tx_data <= sec_10;
                                5'd18:  tx_data <= sec_1;
                                5'd19:  tx_data <= 8'h0A;  // LF
                                default: tx_data <= 8'h00;
                            endcase
                        end else begin
                            case(byte_cnt)
                                5'd0:  tx_data <= 8'h54; // T
                                5'd1:  tx_data <= 8'h3A; // :
                                5'd2:  tx_data <= tem_10; 
                                5'd3:  tx_data <= tem_1;
                                5'd4:  tx_data <= 8'h2E; // .
                                5'd5:  tx_data <= tem_10_dec;
                                5'd6:  tx_data <= tem_1_dec;
                                5'd7:  tx_data <= 8'h0A; // \n
                                5'd8:  tx_data <= 8'h48; // H
                                5'd9:  tx_data <= 8'h3A; // :
                                5'd10:  tx_data <= hum_10; 
                                5'd11:  tx_data <= hum_1; 
                                5'd12:  tx_data <= 8'h2E; // .
                                5'd13:  tx_data <= hum_10_dec;
                                5'd14:  tx_data <= hum_1_dec;
                                5'd15: tx_data <= 8'h0A;    // \n
                                default: tx_data <= 8'h00;
                            endcase
                        end
                        
                        state <= WAIT;
                    end
                end
                
                WAIT: begin
                    tx_start <= 1'b0; // 1클럭 High 유지 -> Low
                    if (tx_done) begin
                        if (byte_cnt == (print_mode ? 5'd15 : 5'd19)) begin
                            if(print_mode) begin
                                state <= IDLE;
                            end else begin
                                print_mode <= 1;
                                byte_cnt <= 5'd0;
                                state <= SEND;
                            end
                        end else begin
                            byte_cnt <= byte_cnt + 1;
                            state <= SEND; // 다음 글자 전송
                        end
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule