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
    wire [7:0] w_rtc_sec, w_rtc_min, w_rtc_hour, w_rtc_date, w_rtc_month, w_rtc_year;
    wire [7:0] w_alarm_hour, w_alarm_min;

    wire w_cw_tick, w_ccw_tick, w_key_tick;

    wire w_tick_1Hz, w_ds1302_busy;
    wire w_ds1302_write_req, w_set_time_done;
    wire [13:0] w_fnd_in_data;
    wire [47:0] w_time_data;

    wire w_clean_btnL, w_clean_s1, w_clean_s2, w_clean_key;

    btn_debounce u_btn_debounce(
        .clk            (clk),
        .reset          (reset),
        .btn            ({btnL, s1, s2, key}),
        .debounced_btn  ({w_clean_btnL, w_clean_s1, w_clean_s2, w_clean_key})
    );

    tick_gen #(
        .INPUT_FREQ (100_000_000),
        .TICK_Hz    (1)
    ) u_tick_gen(
        .clk    (clk),
        .reset  (reset),
        .tick   (w_tick_1Hz)
    );

    control_tower u_control_tower(
        .clk                    (clk),
        .reset                  (reset),
        .btnL                   (w_clean_btnL),

        .hum_int                (w_hum_int),
        .hum_dec                (w_hum_dec),
        .tem_int                (w_tem_int),
        .tem_dec                (w_tem_dec),
        .rtc_sec                (w_rtc_sec),
        .rtc_min                (w_rtc_min),
        .rtc_hour               (w_rtc_hour),
        .rtc_date               (w_rtc_date),
        .rtc_month              (w_rtc_month),
        .rtc_year               (w_rtc_year),

        .sw0                    (sw),
        .alarm_hour             (w_alarm_hour), 
        .alarm_min              (w_alarm_min), 
        .fnd_data               (w_fnd_in_data)
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
        .write_request  (w_ds1302_write_req),
        .set_time_done  (w_set_time_done),
        .busy           (w_ds1302_busy),

        .i_sec          (w_time_data[7:0]),
        .i_min          (w_time_data[15:8]),
        .i_hour         (w_time_data[23:16]),
        .i_date         (w_time_data[31:24]),
        .i_month        (w_time_data[39:32]),
        .i_year         (w_time_data[47:40]),

        .ce             (ds1302_ce),
        .sclk           (ds1302_sclk),
        .ds1302_data    (ds1302_data),

        .o_sec          (w_rtc_sec),
        .o_min          (w_rtc_min),
        .o_hour         (w_rtc_hour),
        .o_date         (w_rtc_date),
        .o_month        (w_rtc_month),
        .o_year         (w_rtc_year)
    );

    uart_controller u_uart_controller(
        .clk                (clk),
        .reset              (reset),
        .start_trigger      (w_tick_1Hz),
        .set_time_done      (w_set_time_done),
        .ds1302_busy        (w_ds1302_busy),

        .hum_int            (w_hum_int),
        .hum_dec            (w_hum_dec),
        .tem_int            (w_tem_int),
        .tem_dec            (w_tem_dec),

        .rtc_sec            (w_rtc_sec),
        .rtc_min            (w_rtc_min),
        .rtc_hour           (w_rtc_hour),
        .rtc_date           (w_rtc_date),
        .rtc_month          (w_rtc_month),
        .rtc_year           (w_rtc_year),

        .time_data          (w_time_data),
        .set_time_trigger   (w_ds1302_write_req),
        .rx                 (RsRx),
        .tx                 (RsTx)
    );

    fnd_controller u_fnd_controller(
        .clk        (clk),
        .reset      (reset), 
        .in_data    (w_fnd_in_data),
        .seg        (seg),
        .an         (an)
    );

    rotary u_rotary(
        .clk        (clk),
        .reset      (reset),
        .clean_s1   (w_clean_s1),
        .clean_s2   (w_clean_s2), 
        .clean_key  (w_clean_key),
        .cw_tick    (w_cw_tick),
        .ccw_tick   (w_ccw_tick),
        .key_tick   (w_key_tick)
    );

    alarm_controller u_alarm_controller(
        .clk            (clk),
        .reset          (reset),
        .sw0            (sw),
        .cw_tick        (w_cw_tick),
        .ccw_tick       (w_ccw_tick),
        .key_tick       (w_key_tick),

        .current_hour   (w_rtc_hour),
        .current_min    (w_rtc_min),
        .current_sec    (w_rtc_sec),
        .alarm_hour     (w_alarm_hour),
        .alarm_min      (w_alarm_min),

        .led0           (led),  
        .buzzer         (buzzer)
    );

endmodule