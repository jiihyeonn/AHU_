`timescale 1ns / 1ps

module uart_rx #(
    parameter BPS = 9600
) (
    input clk,
    input reset,
    input rx,
    output reg [7:0] data_out,
    output reg rx_done
);
    parameter S_IDLE = 2'b00;
    parameter S_START_BIT = 2'b01;
    parameter S_DATA_8BITS = 2'b10;
    parameter S_STOP_BIT = 2'b11;

    // 9600 * 16 = 153_600
    // 100_000_000 Hz / 153_000 = 651ns ( 651ns 주기로 sampling )
    parameter DIVIDER_CNT = 100_000_000 / (BPS * 16);

    reg [1:0] r_state;          // state S_IDLE --> S_STOP_BIT
    reg [3:0] r_bit_cnt;        // r_data에 저장할 index값
    reg [7:0] r_data;           // rx 포트로부터 들어온 bit를 담을 그릇
    reg [15:0] r_baud_cnt;      // 651ns sampling count
    reg r_baud_tick;            // 651ns마다 tick 발생
    reg [3:0] r_baud_tick_cnt;  // 16개 oversampling count

    always @(posedge clk, posedge reset) begin
        if(reset) begin
            r_baud_tick <= 0;
            r_baud_cnt <= 0;
        end else begin
            if(r_baud_cnt >= DIVIDER_CNT - 1) begin
                r_baud_cnt <= 0;
                r_baud_tick <= 1;
            end else begin
                r_baud_cnt <= r_baud_cnt + 1;
                r_baud_tick <= 0;
            end
        end
    end

    always @(posedge clk, posedge reset) begin
        if(reset) begin
            r_state <= S_IDLE;
            r_bit_cnt <= 0;
            r_data <= 0;
            rx_done <= 0;
            r_baud_tick_cnt <= 0;
            data_out <= 0;
        end else begin
            case(r_state)
            S_IDLE: begin
                rx_done <= 0;
                r_data <= 0;
                if(!rx) begin
                    r_baud_tick_cnt <= 0;
                    r_state <= S_START_BIT;
                end
            end

            S_START_BIT: begin
                if(r_baud_tick) begin
                    r_baud_tick_cnt <= r_baud_tick_cnt + 1;
                    if(r_baud_tick_cnt >= 7) begin
                        r_state <= S_DATA_8BITS;
                        r_bit_cnt <= 0;
                        r_baud_tick_cnt <= 0;
                    end
                end
            end

            S_DATA_8BITS: begin
                if(r_baud_tick) begin
                    r_baud_tick_cnt <= r_baud_tick_cnt + 1;
                    if(r_baud_tick_cnt >= 15) begin
                        r_data[r_bit_cnt] = rx;
                        r_baud_tick_cnt <= 0;
                        if(r_bit_cnt == 7) begin
                            r_state <= S_STOP_BIT;
                        end else begin
                            r_bit_cnt <= r_bit_cnt + 1;
                        end
                    end
                end
            end

            S_STOP_BIT: begin
                if(r_baud_tick) begin
                    r_baud_tick_cnt <= r_baud_tick_cnt + 1;
                    if(r_baud_tick_cnt >= 15) begin
                        r_state <= S_IDLE;
                        data_out <= r_data;
                        rx_done <= 1;
                    end
                end
            end

            default: r_state <= S_IDLE;
            endcase
        end
    end
endmodule
