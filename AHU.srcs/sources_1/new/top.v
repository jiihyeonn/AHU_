`timescale 1ns / 1ps

module top(
    input clk,
    input reset, // sw15
    inout dht11_data,

    output ds1302_ce,
    output ds1302_sclk, 
    inout ds1302_data, 
    
    input s1,
    input s2,
    input key,

    input sw,
    input btnL,
    input RsRx,
    output RsTx,
    output led,
    output buzzer,
    output [7:0] seg,
    output [3:0] an
    );

    wire [7:0] w_hum_int, w_hum_dec, w_tem_int, w_tem_dec;
    wire [7:0] w_rtc_sec, w_rtc_min, w_rtc_hour, w_rtc_day, w_rtc_month, w_rtc_year;
    wire [7:0] w_alarm_hour, w_alarm_min;
     
    wire [13:0] w_fnd_in_data;
    wire w_tick_1Hz;
    wire w_cw_tick, w_ccw_tick, w_key_tick;

    wire [7:0] w_set_year, w_set_month, w_set_day, w_set_hour, w_set_min, w_set_sec;
    wire w_set_time_trigger;

    wire w_clean_btnL, w_clean_s1, w_clean_s2, w_clean_key;

    btn_debounce u_btn_debounce(
    .clk(clk),
    .reset(reset),
    .btn({btnL, s1, s2, key}),
    .debounced_btn({w_clean_btnL, w_clean_s1, w_clean_s2, w_clean_key})
    );

    tick_gen #(.INPUT_FREQ (100_000_000), .TICK_Hz(1)) u_tick_gen(
        .clk    (clk),
        .reset  (reset),
        .tick   (w_tick_1Hz)
    );

    control_tower u_control_tower(
        .clk        (clk),
        .reset      (reset),
        .btnL       (w_clean_btnL), 
        .hum_int    (w_hum_int),
        .hum_dec    (w_hum_dec),
        .tem_int    (w_tem_int),
        .tem_dec    (w_tem_dec),
        .rtc_sec    (w_rtc_sec),
        .rtc_min    (w_rtc_min),
        .rtc_hour   (w_rtc_hour),
        .rtc_day    (w_rtc_day),
        .rtc_month  (w_rtc_month),
        .rtc_year   (w_rtc_year),
        .sw0(sw),
        .alarm_hour(w_alarm_hour), 
        .alarm_min(w_alarm_min), 
        .fnd_data   (w_fnd_in_data) 
    );

    dht_controller u_dht_controller(
        .clk            (clk),
        .reset          (reset),
        .start_trigger  (w_tick_1Hz),
        .dht11_data     (dht11_data),
        .hum_int        (w_hum_int),
        .hum_dec        (w_hum_dec),
        .tem_int        (w_tem_int),
        .tem_dec        (w_tem_dec)
    );

    ds1302_controller u_ds1302(
        .clk            (clk),
        .reset          (reset),
        .start_trigger  (w_tick_1Hz),
        .set_year         (w_set_year),
        .set_month        (w_set_month),
        .set_day          (w_set_day),
        .set_hour         (w_set_hour),
        .set_min          (w_set_min),
        .set_sec          (w_set_sec),
        .set_time_trigger (w_set_time_trigger),
        .ce             (ds1302_ce),
        .sclk           (ds1302_sclk),
        .ds1302_data    (ds1302_data),
        .o_sec          (w_rtc_sec),
        .o_min          (w_rtc_min),
        .o_hour         (w_rtc_hour),
        .o_day          (w_rtc_day),
        .o_month        (w_rtc_month),
        .o_year         (w_rtc_year)
    );

    uart_controller u_uart_controller(
        .clk            (clk),
        .reset          (reset),
        .start_trigger  (w_tick_1Hz),
        .hum_int        (w_hum_int),
        .tem_int        (w_tem_int),
        .rtc_year       (w_rtc_year),
        .rtc_month      (w_rtc_month),
        .rtc_day        (w_rtc_day),
        .rtc_hour       (w_rtc_hour),
        .rtc_min        (w_rtc_min),
        .rtc_sec        (w_rtc_sec),
        .set_year         (w_set_year),
        .set_month        (w_set_month),
        .set_day          (w_set_day),
        .set_hour         (w_set_hour),
        .set_min          (w_set_min),
        .set_sec          (w_set_sec),
        .set_time_trigger (w_set_time_trigger),
        .rx             (RsRx),
        .tx             (RsTx),
        .rx_data        (),
        .rx_done        ()
    );

    fnd_controller u_fnd_controller(
        .clk        (clk),
        .reset      (reset), 
        .in_data    (w_fnd_in_data),
        .seg        (seg),
        .an         (an)
    );

    rotary u_rotary(
        .clk(clk),
        .reset(reset),
        .clean_s1(w_clean_s1),
        .clean_s2(w_clean_s2), 
        .clean_key(w_clean_key),
        .cw_tick(w_cw_tick),
        .ccw_tick(w_ccw_tick),
        .key_tick(w_key_tick)
    );

    alarm_controller u_alarm_controller(
    .clk(clk),
    .reset(reset),
    .sw0(sw),         
    .cw_tick(w_cw_tick),
    .ccw_tick(w_ccw_tick),
    .key_tick(w_key_tick),
    .current_hour(w_rtc_hour),
    .current_min(w_rtc_min),
    .current_sec(w_rtc_sec),
    .alarm_hour(w_alarm_hour),
    .alarm_min(w_alarm_min),
    .led0(led),  
    .buzzer(buzzer)
);


endmodule