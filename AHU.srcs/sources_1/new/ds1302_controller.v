`timescale 1ns / 1ps

module ds1302_controller(
    input clk,
    input reset,
    input start_trigger,
    input write_request,
    input [7:0] i_sec,
    input [7:0] i_min,
    input [7:0] i_hour,
    input [7:0] i_date,
    input [7:0] i_month,
    input [7:0] i_year,
    output ce,
    output sclk,
    inout ds1302_data,

    output reg set_time_done,
    output reg busy,
    output reg [7:0] o_sec,
    output reg [7:0] o_min,
    output reg [7:0] o_hour,
    output reg [7:0] o_date,
    output reg [7:0] o_month,
    output reg [7:0] o_year
);
    wire w_io_mode, w_o_data, w_i_data, w_done;

    localparam IDLE           = 4'd0;
    localparam WP_OFF         = 4'd1;
    localparam WRITE_DATA     = 4'd2;
    localparam WP_ON          = 4'd3;
    localparam READ_DATA      = 4'd4;

    localparam READ_SEC     = 8'h81;
    localparam READ_MIN     = 8'h83;
    localparam READ_HOUR    = 8'h85;
    localparam READ_DATE    = 8'h87;
    localparam READ_MONTH   = 8'h89;
    localparam READ_YEAR    = 8'h8D;

    localparam WRITE_SEC    = 8'h80;
    localparam WRITE_MIN    = 8'h82;
    localparam WRITE_HOUR   = 8'h84;
    localparam WRITE_DATE   = 8'h86;
    localparam WRITE_MONTH  = 8'h88;
    localparam WRITE_YEAR   = 8'h8C;
    localparam WRITE_WP     = 8'h8E;

    reg [2:0] state;
    reg rw;   // rw:0 -> write, 1 -> read
    reg start;
    reg [7:0] wr_data;
    wire [7:0] rd_data;
    reg [7:0] cmd;

    function [7:0] from_bcd;
        input [7:0] val;
        begin
            from_bcd = ((val[7:4] * 10) + val[3:0]);
        end
    endfunction

    ds1302_logic u_ds1302_logic(
        .clk            (clk),
        .reset          (reset),
        .start          (start),
        .i_data         (w_i_data),
        .rw             (rw),
        .cmd            (cmd),
        .wr_data        (wr_data),
        .rd_data        (rd_data),
        .ce             (ce),
        .sclk           (sclk),
        .io_mode        (w_io_mode),
        .o_data         (w_o_data),
        .done           (w_done)
    );

    ds1302 u_ds1302(
        .io_mode        (w_io_mode),
        .o_data         (w_o_data),
        .i_data         (w_i_data),
        .ds1302_data    (ds1302_data)
    );

    always @(posedge clk, posedge reset) begin
        if(reset) begin
            state <= IDLE;
            start <= 0;
            rw <= 0;
            busy <= 0;
            cmd <= 8'h00;
            wr_data <= 8'h00;
        end else begin
            start <= 0;
            set_time_done <= 0;

            case(state)
                IDLE: begin
                    busy <= 0;
                    if(write_request) begin
                        busy <= 1;
                        rw <= 0;
                        cmd <= WRITE_WP;
                        wr_data <= 8'h00;
                        start <= 1;
                        state <= WP_OFF;
                    end else if(start_trigger) begin
                        busy <= 1;
                        rw <= 1;
                        cmd <= READ_SEC;
                        start <= 1;
                        state <= READ_DATA;
                    end
                end

                WP_OFF: begin
                    if(w_done) begin
                        cmd <= WRITE_SEC;
                        wr_data <= i_sec & 8'h7F;
                        start <= 1;
                        state <= WRITE_DATA;
                    end
                end

                WRITE_DATA: begin
                    if(w_done) begin
                        case(cmd)
                            WRITE_SEC: begin
                                cmd <= WRITE_MIN;
                                wr_data <= i_min;
                            end
                            WRITE_MIN: begin
                                cmd <= WRITE_HOUR;
                                wr_data <= i_hour;
                            end
                            WRITE_HOUR: begin
                                cmd <= WRITE_DATE;
                                wr_data <= i_date;
                            end
                            WRITE_DATE: begin
                                cmd <= WRITE_MONTH;
                                wr_data <= i_month;
                            end
                            WRITE_MONTH: begin
                                cmd <= WRITE_YEAR;
                                wr_data <= i_year;
                            end
                            WRITE_YEAR: begin
                                cmd <= WRITE_WP;
                                wr_data <= 8'h80;
                                state <= WP_ON;
                            end
                        endcase
                        start <= 1;
                    end
                end

                WP_ON: begin
                    if(w_done) begin
                        set_time_done <= 1;
                        state <= IDLE;
                    end
                end

                READ_DATA: begin
                    if(w_done) begin
                        case(cmd)
                            READ_SEC: begin
                                cmd <= READ_MIN;
                                o_sec <= from_bcd(rd_data & 8'h7F);
                                start <= 1;
                            end
                            READ_MIN: begin
                                cmd <= READ_HOUR;
                                o_min <= from_bcd(rd_data & 8'h7F);
                                start <= 1;
                            end
                            READ_HOUR: begin
                                cmd <= READ_DATE;
                                o_hour <= from_bcd(rd_data & 8'h3F);
                                start <= 1;
                            end
                            READ_DATE: begin
                                cmd <= READ_MONTH;
                                o_date <= from_bcd(rd_data & 8'h3F);
                                start <= 1;
                            end
                            READ_MONTH: begin
                                cmd <= READ_YEAR;
                                o_month <= from_bcd(rd_data & 8'h1F);
                                start <= 1;
                            end
                            READ_YEAR: begin
                                o_year <= from_bcd(rd_data);
                                state <= IDLE;
                            end
                        endcase
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule

module ds1302_logic(
    input clk,
    input reset,
    input start,
    input i_data,
    input rw,
    input [7:0] cmd,
    input [7:0] wr_data,
    output reg [7:0] rd_data,

    output reg ce,
    output reg sclk,
    output reg io_mode, // 1: input, 0: output
    output reg o_data,
    output reg done
);
    localparam IDLE         = 4'd0;
    localparam CE_HIGH      = 4'd1;
    localparam SEND_CMD     = 4'd2;
    localparam RW_DATA      = 4'd3;
    localparam CE_LOW       = 4'd4;

    localparam DIVIDER      = 50;

    reg [2:0] state;
    reg [7:0] shifter;
    reg [7:0] rd_shifter;
    reg [3:0] bit_cnt;  // bit 수
    reg [21:0] counter;
    
    // FSM
    always @(posedge clk, posedge reset) begin
        if(reset) begin
            state <= IDLE;
            rd_data <= 8'h00;
            shifter <= 8'h00;
            rd_shifter <= 8'h00;
            done <= 0;
            ce <= 0;
            sclk <= 0;
            io_mode <= 0;
            o_data <= 0;
            bit_cnt <= 0;
            counter <= 0;
        end else begin
            done <= 0;
            case(state)
                IDLE: begin
                    ce <= 0;
                    sclk <= 0;
                    bit_cnt <= 0;
                    io_mode <= 1;   // 기본 input mode
                    o_data <= 0;

                    if(start) begin
                        shifter <= cmd;
                        rd_shifter <= 8'h00;
                        state <= CE_HIGH;
                    end
                end

                CE_HIGH: begin
                    ce <= 1;    // ce를 high (start)
                    io_mode <= 0;   // 출력모드로
                    o_data <= cmd[0];
                    state <= SEND_CMD;
                end

                SEND_CMD: begin
                    if(counter >= DIVIDER - 1) begin
                        counter <= 0;
                        sclk <= ~sclk;
                        if(sclk) begin // 하강엣지
                            shifter <= {1'b0, shifter[7:1]};

                            if(bit_cnt >= 7) begin
                                bit_cnt <= 0;
                                if(rw) begin
                                    io_mode <= 1;   // 입력모드로
                                    rd_shifter <= 8'h00;
                                end else begin
                                    shifter <= wr_data;
                                    io_mode <= 0;
                                    o_data <= wr_data[0];
                                end
                                state <= RW_DATA;
                            end else begin
                                bit_cnt <= bit_cnt + 1;
                                o_data <= shifter[1];
                            end
                        end
                    end else begin
                        counter <= counter + 1;
                    end
                end

                RW_DATA: begin
                    if(counter >= DIVIDER - 1) begin
                        counter <= 0;
                        sclk <= ~sclk;
                        if(sclk) begin
                            if(rw) begin
                                rd_shifter <= {i_data, rd_shifter[7:1]};
                            end else begin
                                shifter <= {1'b0, shifter[7:1]};
                                o_data <= shifter[1];
                            end

                            if(bit_cnt >= 7) begin
                                if(rw)
                                    rd_data <= {i_data, rd_shifter[7:1]};
                                state <= CE_LOW;
                            end else begin
                                bit_cnt <= bit_cnt + 1;
                            end
                        end
                    end else begin
                        counter <= counter + 1;
                    end
                end

                CE_LOW: begin
                    ce <= 0;
                    io_mode <= 1;
                    done <= 1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
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
