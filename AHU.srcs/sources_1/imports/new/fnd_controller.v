`timescale 1ns / 1ps

module fnd_controller(
    input clk,
    input reset,
    input [13:0] in_data,
    output [3:0] an,
    output [7:0] seg
);
    wire [1:0] w_sel;
    wire [3:0] w_d1, w_d10, w_d100, w_d1000;

    fnd_digit_select u_fnd_digit_select(
        .clk   (clk),
        .reset (reset),
        .sel   (w_sel)
    );

    bin2bdc4digit u_bin2bdc4digit(
        .in_data    (in_data),
        .d1         (w_d1),
        .d10        (w_d10),
        .d100       (w_d100),
        .d1000      (w_d1000)
    );

    fnd_digit_display u_fnd_digit_display(
        .digit_sel  (w_sel),
        .d1         (w_d1),
        .d10        (w_d10),
        .d100       (w_d100),
        .d1000      (w_d1000),
        .an         (an),
        .seg        (seg)
    );

endmodule

module fnd_digit_select(
    input clk,
    input reset,
    output reg [1:0] sel    // 00 01 10 11 : 1ms마다 바뀜
);
    reg[$clog2(100_000):0] r_1ms_counter = 0;

    always @(posedge reset, posedge clk) begin
        if(reset) begin
            r_1ms_counter <= 0;
            sel <= 0;
        end else begin
            if(r_1ms_counter == 100_000 - 1) begin
                r_1ms_counter <= 0;
                sel <= sel + 1;
            end else begin
                r_1ms_counter <= r_1ms_counter + 1;
            end
        end
    end
endmodule


module bin2bdc4digit(
    input [13:0] in_data,
    output [3:0] d1,
    output [3:0] d10,
    output [3:0] d100,
    output [3:0] d1000
);
    assign d1 = in_data % 10;
    assign d10 = (in_data / 10) % 10;
    assign d100 = (in_data / 100) % 10;
    assign d1000 = (in_data / 1000) % 10;
endmodule


module fnd_digit_display(
    input [1:0] digit_sel,
    input [3:0] d1,
    input [3:0] d10,
    input [3:0] d100,
    input [3:0] d1000,
    output reg [3:0] an,
    output reg [7:0] seg
);
    reg [3:0] bcd_data;
    reg dot;    // 분.초를 위한 dot

    always @(digit_sel) begin
        case(digit_sel) 
            2'b00: begin
                dot = 0;
                bcd_data = d1;
                an = 4'b1110;
            end
            2'b01: begin
                dot = 0;
                bcd_data = d10;
                an = 4'b1101;
            end
            2'b10: begin
                dot = 1;
                bcd_data = d100;
                an = 4'b1011;
            end
            2'b11: begin
                dot = 0;
                bcd_data = d1000;
                an = 4'b0111;
            end
            default: begin
                dot = 0;
                bcd_data = 0;
                an = 4'b1111;
            end
        endcase
    end

    always @(bcd_data) begin
        case(bcd_data)
            4'd0: seg = 8'b11000000;
            4'd1: seg = 8'b11111001;
            4'd2: seg = 8'b10100100;
            4'd3: seg = 8'b10110000;
            4'd4: seg = 8'b10011001;
            4'd5: seg = 8'b10010010;
            4'd6: seg = 8'b10000010;
            4'd7: seg = 8'b11111000;
            4'd8: seg = 8'b10000000;
            4'd9: seg = 8'b10010000;
            default: seg = 8'b11111111;
        endcase

        if(dot) begin
            seg[7] = 0;
        end
    end
endmodule