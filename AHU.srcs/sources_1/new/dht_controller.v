`timescale 1ns / 1ps

module dht_controller(
    input clk,
    input reset,
    input start_trigger,
    inout dht11_data,

    output [7:0] hum_int,
    output [7:0] hum_dec,
    output [7:0] tem_int,
    output [7:0] tem_dec
);
    wire w_io_mode, w_o_data, w_i_data;

    dht11 u_dht11(
        .io_mode    (w_io_mode),
        .o_data     (w_o_data),
        .i_data     (w_i_data),
        .dht11_data (dht11_data)
    );

    dht11_main_logic u_dht11_main_logic(
        .clk            (clk),
        .reset          (reset),
        .start_trigger  (start_trigger),
        .i_data         (w_i_data),
        .o_data         (w_o_data),
        .io_mode        (w_io_mode),
        .hum_int        (hum_int),
        .hum_dec        (hum_dec),
        .tem_int        (tem_int),
        .tem_dec        (tem_dec)
    );

endmodule


module dht11_main_logic(
    input clk,
    input reset,
    input start_trigger,
    input i_data,
    output reg o_data,
    output reg io_mode,
    output reg [7:0] hum_int,
    output reg [7:0] hum_dec,
    output reg [7:0] tem_int,
    output reg [7:0] tem_dec
);
    localparam IDLE                 = 4'd0;
    localparam START_LOW            = 4'd1;
    localparam START_PULL_UP        = 4'd2;
    localparam WAIT_LOW_HIGH        = 4'd3;
    localparam WAIT_BIT_LOW         = 4'd4;
    localparam CHECK_HIGH_DURATION  = 4'd5;
    localparam STORE_BIT            = 4'd6;
    localparam CHECK_DATA           = 4'd7;

    localparam TIME_18mS            = 1_800_000;
    localparam TIME_30uS            = 3_000;
    localparam TIME_160uS           = 16_000;
    localparam TIME_BIT_THRESHOLD   = 5_000;

    reg [21:0] counter;

    reg [3:0] state;
    reg i_data_ff1, i_data_ff2;
    reg low_high;

    reg [15:0] high_time_cnt;   // 데이터 high 시간 감지할 counter
    reg [39:0] data;
    reg [5:0] data_bit_cnt; // 데이터 bit counter
    reg recieved_bit;

    // 2단 FF
    always @(posedge clk, posedge reset) begin
        if(reset) begin
            i_data_ff1 <= 1;    // 기본 i_data는 idle 상태에서 1
            i_data_ff2 <= 1;
        end else begin
            i_data_ff1 <= i_data;
            i_data_ff2 <= i_data_ff1;
        end
    end

    // FSM
    always @(posedge clk, posedge reset) begin
        if(reset) begin
            state <= IDLE;
            io_mode <= 1;   // input mode
            o_data <= 1;    // pull_down 18ms를 제외하면 항상 1
            
            counter <= 0;

            high_time_cnt <= 0;
            data <= 0;
            data_bit_cnt <= 0;
            low_high <= 0;

            hum_int <= 0;
            hum_dec <= 0;
            tem_int <= 0;
            tem_dec <= 0;
        end else begin
            case(state)
                IDLE: begin
                    io_mode <= 1;
                    o_data <= 1;
                    high_time_cnt <= 0;
                    data <= 0;
                    data_bit_cnt <= 0;
                    low_high <= 0;
                    counter <= 0;

                    if(start_trigger) begin
                        state <= START_LOW;
                    end
                end

                // 18ms start signal low
                START_LOW: begin
                    io_mode <= 0;   // output mode
                    o_data <= 0;    // pull down 동작

                    if(counter >= TIME_18mS - 1) begin
                        counter <= 0;
                        state <= START_PULL_UP;
                    end else begin
                        counter <= counter + 1;
                    end
                end

                // 30us start signal high
                START_PULL_UP: begin
                    o_data <= 1;

                    if(counter >= TIME_30uS - 1) begin
                        counter <= 0;
                        state <= WAIT_LOW_HIGH;
                    end else begin
                        counter <= counter + 1;
                    end
                end
                
                WAIT_LOW_HIGH: begin
                    io_mode <= 1;   // input mode
                    
                    // rise, fall edge를 기다림
                    if(i_data_ff1 && !i_data_ff2) begin
                        low_high <= 1;
                    end else if(low_high && !i_data_ff1 && i_data_ff2) begin
                        low_high <= 0;
                        state <= WAIT_BIT_LOW;
                    end
                    // 응답 기다림 80us low, 80us high  오류 검출 필요
                    // if(counter >= TIME_160uS - 1) begin
                    //     counter <= 0;
                    //     state <= WAIT_BIT_LOW;
                    // end else begin
                    //     counter <= counter + 1;
                    // end
                end

                // data 전송 과정에서 high가 들어오기를 기다림
                WAIT_BIT_LOW: begin
                    if(i_data_ff1 && !i_data_ff2) begin // 상승엣지를 만나면 state 변경
                        state <= CHECK_HIGH_DURATION;
                    end
                end

                // high 시간 측정
                CHECK_HIGH_DURATION: begin
                    if(!i_data_ff1 && i_data_ff2) begin // 하강엣지일때
                        // 50us를 기준으로 1, 0 확인
                        if(high_time_cnt >= TIME_BIT_THRESHOLD) begin
                            recieved_bit <= 1;
                        end else begin
                            recieved_bit <= 0;
                        end
                        state <= STORE_BIT;
                    end else begin
                        if(high_time_cnt < 16'hffff) begin  // 하강엣지 안들어오는 경우 방지
                            high_time_cnt <= high_time_cnt + 1;
                        end
                    end
                end

                // data에 bit 저장
                STORE_BIT: begin
                    high_time_cnt <= 0;
                    // shift 시켜가며 밀기
                    data <= {recieved_bit, data[39:1]};

                    if(data_bit_cnt >= 39) begin
                        state <= CHECK_DATA;
                    end else begin
                        data_bit_cnt <= data_bit_cnt + 1;
                        state <= WAIT_BIT_LOW;
                    end
                end

                // check sum error 탐지
                CHECK_DATA : begin
                    if ((data[7:0] + data[15:8] +
                         data[23:16] + data[31:24]) == data[39:32]) begin
                        tem_int <= data[7:0];
                        tem_dec <= data[15:8];
                        hum_int <= data[23:16];
                        hum_dec <= data[31:24];
                    end else begin
                        // error 처리 필요
                        hum_int <= 0;
                        hum_dec <= 0;
                        tem_int <= 0;
                        tem_dec <= 0;
                    end
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule


module dht11(
    input io_mode,
    input o_data,
    output i_data,
    inout dht11_data
);
    assign dht11_data = io_mode ? 1'bz : o_data;
    assign i_data = dht11_data;
endmodule
