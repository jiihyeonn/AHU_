`timescale 1ns / 1ps

module tb_data_receiver();
    reg clk;
    reg reset;
    reg rx_done;
    reg [7:0] rx_data;
    reg set_time_done;
    wire set_time_trigger;
    wire [47:0] time_data;

    data_receiver u_data_receiver(
        .clk(clk),
        .reset(reset),
        .rx_done(rx_done),
        .rx_data(rx_data),
        .set_time_done(set_time_done),
        .set_time_trigger(set_time_trigger),
        .time_data(time_data)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 0; rx_done = 0; rx_data = 8'd0; set_time_done = 0;
        reset = 1; #100
        reset = 0; #200

        // setrtc
        rx_data = 8'h73; rx_done = 1; #10; rx_done = 0; #160_000;
        rx_data = 8'h65; rx_done = 1; #10; rx_done = 0; #160_000;
        rx_data = 8'h74; rx_done = 1; #10; rx_done = 0; #160_000;
        rx_data = 8'h72; rx_done = 1; #10; rx_done = 0; #160_000;
        rx_data = 8'h74; rx_done = 1; #10; rx_done = 0; #160_000;
        rx_data = 8'h63; rx_done = 1; #10; rx_done = 0; #160_000;

        // yymmddhhmmss
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
        rx_data = 8'h0A; rx_done = 1; #10; rx_done = 0; #160_000;

        #1_000_000; // 1ms 대기
        set_time_done = 1; #10; set_time_done = 0;
        $finish;
    end

endmodule
