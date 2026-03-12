`timescale 1ns / 1ps

module data_receiver(
    input clk,
    input reset,
    input rx_done,
    input [7:0] rx_data,
    input set_time_done,
    output reg set_time_trigger,
    output reg [47:0] time_data
);
    function [3:0] to_num;
        input [7:0] ascii;
        begin
            to_num = ascii - 8'h30;
        end
    endfunction

    localparam TIME_OUT_DURATION = 1_000_000; // 10ms timeout duration
    reg busy;
    reg [7:0] c_queue [15:0][19:0];
    reg [3:0] rear, front;
    reg [4:0] byte_cnt;
    integer i, j;
    reg [$clog2(TIME_OUT_DURATION)-1:0] time_out_cnt;

    always @(posedge clk, posedge reset) begin
        if(reset) begin
            for(i=0;i<16;i=i+1) begin
                for(j=0;j<20;j=j+1) begin
                    c_queue[i][j] <= 0;
                end
            end
            rear <= 0;
            front <= 0;
            byte_cnt <= 0;
            busy <= 0;
            set_time_trigger <= 0;
            time_data <= 48'd0;
            time_out_cnt <= 0;
        end else begin
            set_time_trigger <= 0;
            if(rx_done) begin
                if(rx_data == 8'h0A) begin  // 개행문자를 기준으로 cicler queue에 저장
                    front <= (front == 4'd15) ? 0 : front + 1;  // front 증가
                    if(front == rear-1) rear <= rear + 1;
                    byte_cnt <= 0;
                end else if(rx_data != 8'h0D) begin
                    byte_cnt <= byte_cnt + 1;
                    c_queue[front][byte_cnt] <= rx_data;    // front 위치에 byte 저장
                end
            end

            if(!busy) begin
                if(rear != front) begin // set time 데이터가 있다는 뜻
                    if({c_queue[rear][0],
                    c_queue[rear][1],
                    c_queue[rear][2],
                    c_queue[rear][3],
                    c_queue[rear][4],
                    c_queue[rear][5]} == "setrtc") begin
                        for(i=0;i<12;i=i+1) begin
                            time_data[4*(11-i) +: 4] <= to_num(c_queue[rear][i+6]);
                        end
                        set_time_trigger <= 1;
                        busy <= 1;
                    end
                end
            end else begin
                if(time_out_cnt >= TIME_OUT_DURATION) begin
                    time_out_cnt <= 0;
                    busy <= 0;
                    time_data <= 48'd0;
                    // time out error
                end else begin
                    if(set_time_done) begin
                        if(rear != front) begin
                            rear <= rear + 1;   // set한 데이터는 삭제
                        end
                        time_out_cnt <= 0;
                        busy <= 0;
                        time_data <= 48'd0;
                    end else begin
                        time_out_cnt <= time_out_cnt + 1;
                    end
                end
            end
        end
    end
endmodule
