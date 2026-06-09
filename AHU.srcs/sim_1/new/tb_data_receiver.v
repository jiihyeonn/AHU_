`timescale 1ns / 1ps

module tb_data_receiver();
    // inputs
    reg clk;
    reg reset;
    reg rx_done;
    reg [7:0] rx_data;
    reg set_time_done;
    reg ds1302_busy;

    // outputs
    wire set_time_trigger;
    wire [47:0] time_data;

    data_receiver u_data_receiver(
        .clk(clk),
        .reset(reset),
        .rx_done(rx_done),
        .rx_data(rx_data),
        .ds1302_busy(ds1302_busy),
        .set_time_done(set_time_done),
        .set_time_trigger(set_time_trigger),
        .time_data(time_data)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 0; rx_done = 0; rx_data = 8'd0; set_time_done = 0; ds1302_busy = 0;
        reset = 1; #100
        reset = 0; #100

        // #1
        // set time command uart rx로 감지되었을 때 가정

        // setrtc (command start)
        rx_data = 8'h73; rx_done = 1; #10; rx_done = 0; #160_000;
        rx_data = 8'h65; rx_done = 1; #10; rx_done = 0; #160_000;
        rx_data = 8'h74; rx_done = 1; #10; rx_done = 0; #160_000;
        rx_data = 8'h72; rx_done = 1; #10; rx_done = 0; #160_000;
        rx_data = 8'h74; rx_done = 1; #10; rx_done = 0; #160_000;
        rx_data = 8'h63; rx_done = 1; #10; rx_done = 0; #160_000;

        // 26.03.09.17.00.00 (date)
        rx_data = 8'h32; rx_done = 1; #10; rx_done = 0; #160_000;
        rx_data = 8'h36; rx_done = 1; #10; rx_done = 0; #160_000;
        rx_data = 8'h30; rx_done = 1; #10; rx_done = 0; #160_000;
        rx_data = 8'h33; rx_done = 1; #10; rx_done = 0; #160_000;
        rx_data = 8'h30; rx_done = 1; #10; rx_done = 0; #160_000;
        rx_data = 8'h39; rx_done = 1; #10; rx_done = 0; #160_000;
        rx_data = 8'h31; rx_done = 1; #10; rx_done = 0; #160_000;
        rx_data = 8'h37; rx_done = 1; #10; rx_done = 0; #160_000;
        rx_data = 8'h30; rx_done = 1; #10; rx_done = 0; #160_000;
        rx_data = 8'h30; rx_done = 1; #10; rx_done = 0; #160_000;
        rx_data = 8'h30; rx_done = 1; #10; rx_done = 0; #160_000;
        rx_data = 8'h30; rx_done = 1; #10; rx_done = 0; #160_000;

        // CRLF
        rx_data = 8'h0D; rx_done = 1; #10; rx_done = 0; #160_000;
        rx_data = 8'h0A; rx_done = 1; #10; rx_done = 0;

        // ds1302 #1 데이터 처리중
        ds1302_busy = 1;
        #160_000;

        // #2
        // set_time_done이 안올라 온 상태 가정

        // setrtc (command start)
        rx_data = 8'h73; rx_done = 1; #10; rx_done = 0; #160_000;
        rx_data = 8'h65; rx_done = 1; #10; rx_done = 0; #160_000;
        rx_data = 8'h74; rx_done = 1; #10; rx_done = 0; #160_000;
        rx_data = 8'h72; rx_done = 1; #10; rx_done = 0; #160_000;
        rx_data = 8'h74; rx_done = 1; #10; rx_done = 0; #160_000;
        rx_data = 8'h63; rx_done = 1; #10; rx_done = 0; #160_000;

        // 26.03.10.18.30.55 (date)
        rx_data = 8'h32; rx_done = 1; #10; rx_done = 0; #160_000;
        rx_data = 8'h36; rx_done = 1; #10; rx_done = 0; #160_000;
        rx_data = 8'h30; rx_done = 1; #10; rx_done = 0; #160_000;
        rx_data = 8'h33; rx_done = 1; #10; rx_done = 0; #160_000;
        rx_data = 8'h31; rx_done = 1; #10; rx_done = 0; #160_000;
        rx_data = 8'h30; rx_done = 1; #10; rx_done = 0; #160_000;
        rx_data = 8'h31; rx_done = 1; #10; rx_done = 0; #160_000;
        rx_data = 8'h38; rx_done = 1; #10; rx_done = 0; #160_000;
        rx_data = 8'h33; rx_done = 1; #10; rx_done = 0; #160_000;
        rx_data = 8'h30; rx_done = 1; #10; rx_done = 0; #160_000;
        rx_data = 8'h35; rx_done = 1; #10; rx_done = 0; #160_000;
        rx_data = 8'h35; rx_done = 1; #10; rx_done = 0; #160_000;

        // CRLF
        rx_data = 8'h0D; rx_done = 1; #10; rx_done = 0; #160_000;
        rx_data = 8'h0A; rx_done = 1; #10; rx_done = 0; #160_000;

        ds1302_busy = 0; #10;
        // set_time_done 올려주기
        set_time_done = 1; #10; set_time_done = 0;
        #100;

        // ds1302 #2 데이터 처리중
        ds1302_busy = 1; #1_000_000;
        // 1ms 후 두번째 set_time_done 올려주기
        ds1302_busy = 0; set_time_done = 1; #10; set_time_done = 0;

        #1_000_000; // 1ms 대기
        $finish;
    end

endmodule
