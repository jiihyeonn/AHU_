`timescale 1ns / 1ps

module uart_controller(
    input clk,
    input reset,
    input start_trigger,
    input set_time_done,
    input ds1302_busy,

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

    input rx,
    output tx,
    output [47:0] time_data,
    output set_time_trigger
);
    wire w_tx_start, w_tx_busy, w_tx_done;
    wire w_rx_done;
    wire [7:0] w_rx_data;
    wire [7:0] w_tx_data;

    data_sender u_data_sender(
        .clk            (clk),
        .reset          (reset),
        .start_trigger  (start_trigger),

        .hum_int        (hum_int),
        .hum_dec        (hum_dec),
        .tem_int        (tem_int),
        .tem_dec        (tem_dec),

        .rtc_sec        (rtc_sec),
        .rtc_min        (rtc_min),
        .rtc_hour       (rtc_hour),
        .rtc_date       (rtc_date),
        .rtc_month      (rtc_month),
        .rtc_year       (rtc_year),

        .tx_busy        (w_tx_busy),
        .tx_done        (w_tx_done),
        .tx_data        (w_tx_data),
        .tx_start       (w_tx_start)
    );

    data_receiver u_data_receiver(
        .clk                (clk),
        .reset              (reset),
        .rx_done            (w_rx_done),
        .rx_data            (w_rx_data),
        .set_time_done      (set_time_done),
        .set_time_trigger   (set_time_trigger),
        .ds1302_busy        (ds1302_busy),
        .time_data          (time_data)
    );

    uart_tx #(
        .BPS(9600)
    ) u_uart_tx(
        .clk        (clk),
        .reset      (reset),
        .tx_data    (w_tx_data),
        .tx_start   (w_tx_start),
        .tx         (tx),
        .tx_done    (w_tx_done),
        .tx_busy    (w_tx_busy)
    );

    uart_rx #(
        .BPS(9600)
    ) u_uart_rx(
        .clk        (clk),
        .reset      (reset),
        .rx         (rx),
        .data_out   (w_rx_data),
        .rx_done    (w_rx_done)
    );

endmodule
