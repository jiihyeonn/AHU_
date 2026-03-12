`timescale 1ns / 1ps

module tb_ds1302();
    reg clk;
    reg reset;
    reg start_trigger;
    wire ce;
    wire sclk;
    wire ds1302_data;
    wire [7:0] o_sec;
    wire [7:0] o_min;
    wire [7:0] o_hour;
    wire [7:0] o_day;
    wire [7:0] o_month;
    wire [7:0] o_year;

    wire i_data;
    assign i_data = ds1302_data;

    ds1302_controller u_ds1302_controller(
        .clk            (clk),
        .reset          (reset),
        .start_trigger  (start_trigger),
        .ce             (ce),
        .sclk           (sclk),
        .ds1302_data    (ds1302_data),
        .o_sec          (o_sec),
        .o_min          (o_min),
        .o_hour         (o_hour),
        .o_day          (o_day),
        .o_month        (o_month),
        .o_year         (o_year)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 0;
        start_trigger = 0;
        reset = 1; #100
        reset = 0; #200

        start_trigger = 1; #5
        start_trigger = 0;
    end
endmodule
