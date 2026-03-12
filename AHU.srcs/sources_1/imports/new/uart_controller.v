`timescale 1ns / 1ps

module uart_controller(
    input clk,
    input reset,
    input [7:0] hum_int, tem_int,
    input [7:0] rtc_year, rtc_month, rtc_day, rtc_hour, rtc_min, rtc_sec, // 현재 시간 입력
    input start_trigger,
    input rx,
    output tx,
    output [7:0] rx_data,
    output rx_done,
    
    // RTC 세팅용 출력 핀들 (DS1302로 보낼 데이터)
    output [7:0] set_year, set_month, set_day, set_hour, set_min, set_sec,
    output set_time_trigger
);
    wire w_tx_start, w_tx_busy, w_tx_done;
    wire [7:0] w_tx_data;
    wire w_rx_done;
    wire [7:0] w_rx_data;

    assign rx_data = w_rx_data;
    assign rx_done = w_rx_done;

    data_sender u_data_sender(
        .clk(clk), 
        .reset(reset), 
        .start_trigger(start_trigger),
        .hum_int(hum_int), 
        .tem_int(tem_int),
        .rtc_year(rtc_year), 
        .rtc_month(rtc_month), 
        .rtc_day(rtc_day),
        .rtc_hour(rtc_hour), 
        .rtc_min(rtc_min), 
        .rtc_sec(rtc_sec),
        .tx_busy(w_tx_busy), 
        .tx_done(w_tx_done), 
        .tx_data(w_tx_data), 
        .tx_start(w_tx_start)
    );

    cmd_receiver u_cmd_receiver(
        .clk(clk), 
        .reset(reset), 
        .rx_data(w_rx_data), 
        .rx_done(w_rx_done),
        .set_year(set_year), 
        .set_month(set_month), 
        .set_day(set_day),
        .set_hour(set_hour), 
        .set_min(set_min), 
        .set_sec(set_sec),
        .set_time_trigger(set_time_trigger)
    );

    uart_tx #(.BPS(9600)) u_uart_tx (
        .clk(clk), 
        .reset(reset), 
        .tx_data(w_tx_data), 
        .tx_start(w_tx_start),
        .tx(tx),
        .tx_done(w_tx_done), 
        .tx_busy(w_tx_busy)
    );

    uart_rx #(.BPS(9600)) u_uart_rx (
        .clk(clk), 
        .reset(reset), 
        .rx(rx), 
        .data_out(w_rx_data), 
        .rx_done(w_rx_done)
    );
endmodule

// === 명령어 해독기 ===
module cmd_receiver(
    input clk, reset,
    input [7:0] rx_data,
    input rx_done,
    output reg [7:0] set_year, set_month, set_day, set_hour, set_min, set_sec,
    output reg set_time_trigger
);
    reg [143:0] rx_buf;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            rx_buf <= 0; set_time_trigger <= 0;
            set_year <= 0; set_month <= 0; set_day <= 0;
            set_hour <= 0; set_min <= 0; set_sec <= 0;
        end else begin
            set_time_trigger <= 0;
            
            if (rx_done) rx_buf <= {rx_buf[135:0], rx_data};

            // "setrtc" ASCII 감지
            if (rx_buf[143:96] == "setrtc") begin
                set_year  <= ((rx_buf[95:88] - 8'h30) << 4) | (rx_buf[87:80] - 8'h30);
                set_month <= ((rx_buf[79:72] - 8'h30) << 4) | (rx_buf[71:64] - 8'h30);
                set_day   <= ((rx_buf[63:56] - 8'h30) << 4) | (rx_buf[55:48] - 8'h30);
                set_hour  <= ((rx_buf[47:40] - 8'h30) << 4) | (rx_buf[39:32] - 8'h30);
                set_min   <= ((rx_buf[31:24] - 8'h30) << 4) | (rx_buf[23:16] - 8'h30);
                set_sec   <= ((rx_buf[15:8]  - 8'h30) << 4) | (rx_buf[7:0]   - 8'h30); 
                
                set_time_trigger <= 1'b1; 
                rx_buf <= 0;
            end
        end
    end
endmodule