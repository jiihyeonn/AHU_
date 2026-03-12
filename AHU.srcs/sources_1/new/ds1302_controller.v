`timescale 1ns / 1ps

module ds1302_controller(
    input clk, reset, start_trigger,

    input [7:0] set_year, set_month, set_day, set_hour, set_min, set_sec,
    input set_time_trigger, 
    
    output ce, sclk,
    inout ds1302_data,
    output [7:0] o_sec, o_min, o_hour, o_day, o_month, o_year
);
    wire w_io_mode, w_o_data, w_i_data;

    ds1302_main_logic u_ds1302_main_logic(
        .clk(clk), 
        .reset(reset), 
        .start_trigger(start_trigger),
        .set_year(set_year), 
        .set_month(set_month), 
        .set_day(set_day),
        .set_hour(set_hour), 
        .set_min(set_min), 
        .set_sec(set_sec),
        .set_time_trigger(set_time_trigger),
        .i_data(w_i_data), 
        .ce(ce), 
        .sclk(sclk), 
        .io_mode(w_io_mode), 
        .o_data(w_o_data),
        .o_sec(o_sec), 
        .o_min(o_min), 
        .o_hour(o_hour), 
        .o_day(o_day), 
        .o_month(o_month), 
        .o_year(o_year)
    );

    ds1302 u_ds1302(
        .io_mode(w_io_mode), 
        .o_data(w_o_data), 
        .i_data(w_i_data), 
        .ds1302_data(ds1302_data)
    );
endmodule

module ds1302_main_logic(
    input clk, reset, start_trigger,
    input [7:0] set_year, set_month, set_day, set_hour, set_min, set_sec,
    input set_time_trigger,
    input i_data,
    output reg ce, sclk, io_mode, o_data,
    output reg [7:0] o_sec, o_min, o_hour, o_day, o_month, o_year
);

    localparam IDLE         = 4'd0;
    localparam CHOOSE_CMD   = 4'd1;
    localparam CE_HIGH      = 4'd2;
    localparam SEND_CMD     = 4'd3;
    localparam READ_DATA    = 4'd4;
    localparam WRITE_DATA   = 4'd5;
    localparam CE_LOW       = 4'd6;
    localparam STORE_DATA   = 4'd7;

    localparam WAIT_TO_READ = 8'h00;
    localparam READ_SECOND  = 8'h81;
    localparam READ_MINUTE  = 8'h83;
    localparam READ_HOUR    = 8'h85;
    localparam READ_DAY     = 8'h87;
    localparam READ_MONTH   = 8'h89;
    localparam READ_YEAR    = 8'h8D;

    localparam WRITE_WP     = 8'h8E;
    localparam WRITE_SECOND = 8'h80;
    localparam DIVIDER      = 50;

    reg [3:0] state, bit_cnt;  
    reg [7:0] cmd_reg, data_reg, write_data_reg;
    reg init_done, is_write_op, sclk_state;
    reg [1:0] init_step;
    reg [21:0] counter;
    
    reg is_time_setting;
    reg [2:0] set_seq;
    
    // 트리거 감지 (어느 상태에 있든 트리거가 들어오면 바로 예약)
    always @(posedge clk) begin
        if (set_time_trigger) is_time_setting <= 1'b1;
        // 처리가 끝나면 IDLE에서 0으로 내림
    end

    always @(posedge clk or posedge reset) begin
        if(reset) begin
            state <= IDLE; ce <= 0; io_mode <= 0; o_data <= 0;
            bit_cnt <= 0; sclk <= 0; init_done <= 0; init_step <= 0; 
            is_write_op <= 0; sclk_state <= 0;
            is_time_setting <= 0; set_seq <= 0; // 초기화
            cmd_reg <= WAIT_TO_READ;
            o_sec <= 0; o_min <= 0; o_hour <= 0; o_day <= 0; o_month <= 0; o_year <= 0;
        end else begin
            case(state)
                IDLE: begin
                    ce <= 0; sclk <= 0; bit_cnt <= 0;
                    io_mode <= 0; o_data <= 0; sclk_state <= 0;
                    
                    //  PC에서 시간 보정 
                    if (is_time_setting) begin
                        is_write_op <= 1;
                        case(set_seq)
                            0: begin cmd_reg <= 8'h8E; write_data_reg <= 8'h00;     state <= CE_HIGH; end // WP 해제
                            1: begin cmd_reg <= 8'h8C; write_data_reg <= set_year;  state <= CE_HIGH; end // 년 쓰기
                            2: begin cmd_reg <= 8'h88; write_data_reg <= set_month; state <= CE_HIGH; end // 월 쓰기
                            3: begin cmd_reg <= 8'h86; write_data_reg <= set_day;   state <= CE_HIGH; end // 일 쓰기
                            4: begin cmd_reg <= 8'h84; write_data_reg <= set_hour;  state <= CE_HIGH; end // 시 쓰기
                            5: begin cmd_reg <= 8'h82; write_data_reg <= set_min;   state <= CE_HIGH; end // 분 쓰기
                            6: begin cmd_reg <= 8'h80; write_data_reg <= set_sec;   state <= CE_HIGH; end // 초 쓰기 (동시에 CH=0으로 시계 동작!)
                            7: begin is_time_setting <= 0; set_seq <= 0; end // 보정 완료!
                        endcase
                    end
                    // 최초 전원 인가 시 초기화
                    else if (!init_done) begin
                        is_write_op <= 1;
                        if (init_step == 0) begin
                            cmd_reg <= 8'h8E; write_data_reg <= 8'h00; state <= CE_HIGH;
                        end else if (init_step == 1) begin
                            cmd_reg <= 8'h80; write_data_reg <= 8'h00; state <= CE_HIGH;
                        end else begin
                            init_done <= 1; is_write_op <= 0; cmd_reg <= WAIT_TO_READ;
                        end
                    end 
                    // 평상시 시간 읽기
                    else if (start_trigger) begin
                        state <= CHOOSE_CMD;
                    end
                end

                CHOOSE_CMD: begin
                    is_write_op <= 0;
                    case(cmd_reg)
                        WAIT_TO_READ:   cmd_reg <= READ_SECOND;
                        READ_SECOND:    cmd_reg <= READ_MINUTE;
                        READ_MINUTE:    cmd_reg <= READ_HOUR;
                        READ_HOUR:      cmd_reg <= READ_DAY;
                        READ_DAY:       cmd_reg <= READ_MONTH;
                        READ_MONTH:     cmd_reg <= READ_YEAR;
                        READ_YEAR:      cmd_reg <= WAIT_TO_READ;













                        
                        default:        state <= IDLE;
                    endcase
                    if(cmd_reg == READ_YEAR) state <= IDLE;
                    else state <= CE_HIGH;
                end

                CE_HIGH: begin
                    ce <= 1; io_mode <= 0; bit_cnt <= 0;
                    sclk_state <= 0; counter <= 0;
                    state <= SEND_CMD;
                end

                SEND_CMD: begin
                    if(counter >= DIVIDER - 1) begin
                        counter <= 0;
                        if (sclk_state == 0) begin
                            o_data <= cmd_reg[bit_cnt]; 
                            sclk <= 0; sclk_state <= 1;
                        end else begin
                            sclk <= 1; sclk_state <= 0;
                            if (bit_cnt == 7) begin
                                bit_cnt <= 0;
                                if(is_write_op) state <= WRITE_DATA;
                                else begin
                                    state <= READ_DATA; io_mode <= 1; 
                                end
                            end else bit_cnt <= bit_cnt + 1;
                        end
                    end else counter <= counter + 1;
                end

                WRITE_DATA: begin
                    if(counter >= DIVIDER - 1) begin
                        counter <= 0;
                        if (sclk_state == 0) begin
                            o_data <= write_data_reg[bit_cnt]; 
                            sclk <= 0; sclk_state <= 1;
                        end else begin
                            sclk <= 1; sclk_state <= 0;
                            if (bit_cnt == 7) state <= CE_LOW;
                            else bit_cnt <= bit_cnt + 1;
                        end
                    end else counter <= counter + 1;
                end

                READ_DATA: begin
                    if(counter >= DIVIDER - 1) begin
                        counter <= 0;
                        if (sclk_state == 0) begin
                            sclk <= 0; sclk_state <= 1;
                        end else begin
                            data_reg[bit_cnt] <= i_data; 
                            sclk <= 1; sclk_state <= 0;
                            if (bit_cnt == 7) state <= CE_LOW;
                            else bit_cnt <= bit_cnt + 1;
                        end
                    end else counter <= counter + 1;
                end

                CE_LOW: begin
                    ce <= 0; sclk <= 0; io_mode <= 0;
                    
                    if (is_time_setting) begin
                        set_seq <= set_seq + 1; 
                        state <= IDLE;
                    end
                    else if (!init_done) begin
                        init_step <= init_step + 1; 
                        state <= IDLE;
                    end else begin
                        state <= STORE_DATA; 
                    end
                end

                STORE_DATA: begin
                    case(cmd_reg)
                        READ_SECOND: o_sec   <= (data_reg[6:4] * 10) + data_reg[3:0];
                        READ_MINUTE: o_min   <= (data_reg[6:4] * 10) + data_reg[3:0];
                        READ_HOUR:   o_hour  <= (data_reg[5:4] * 10) + data_reg[3:0]; 
                        READ_DAY:    o_day   <= (data_reg[5:4] * 10) + data_reg[3:0]; 
                        READ_MONTH:  o_month <= (data_reg[4]   * 10) + data_reg[3:0]; 
                        READ_YEAR:   o_year  <= (data_reg[7:4] * 10) + data_reg[3:0];
                        default:     state   <= IDLE;
                    endcase
                    state <= CHOOSE_CMD; 
                end
                default: state <= IDLE;
            endcase
        end
    end
endmodule

module ds1302(
    input io_mode,
    input o_data,
    output i_data,
    inout ds1302_data
);
    assign ds1302_data = io_mode ? 1'bz : o_data;
    assign i_data = ds1302_data;
endmodule