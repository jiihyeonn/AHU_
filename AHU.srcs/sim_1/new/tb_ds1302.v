`timescale 1ns / 1ps

module tb_ds1302_controller;

    // Inputs
    reg clk;
    reg reset;
    reg start_trigger;
    reg write_request;
    reg [7:0] i_sec, i_min, i_hour, i_date, i_month, i_year;

    // Outputs
    wire ce;
    wire sclk;
    wire set_time_done;
    wire busy;
    wire [7:0] o_sec, o_min, o_hour, o_date, o_month, o_year;

    // Inout
    wire ds1302_data;

    // DS1302 Mock을 위한 내부 레지스터
    reg ds1302_data_oe;      // 1이면 Mock DS1302가 데이터 출력, 0이면 High-Z (컨트롤러가 출력)
    reg ds1302_data_out;     // Mock DS1302의 출력 비트
    reg [7:0] shift_reg_in;  // 컨트롤러로부터 받는 Command 저장용
    reg [7:0] shift_reg_out; // 컨트롤러로 보낼 Data 저장용
    integer bit_count;       // SCLK 엣지 카운터

    // Inout 포트 연결: oe가 1일 때만 out 값을 내보내고, 아니면 High-Z 상태
    assign ds1302_data = ds1302_data_oe ? ds1302_data_out : 1'bz;

    ds1302_controller uut (
        .clk(clk), 
        .reset(reset), 
        .start_trigger(start_trigger), 
        .write_request(write_request), 
        .i_sec(i_sec), 
        .i_min(i_min), 
        .i_hour(i_hour), 
        .i_date(i_date), 
        .i_month(i_month), 
        .i_year(i_year), 
        .ce(ce), 
        .sclk(sclk), 
        .ds1302_data(ds1302_data), 
        .set_time_done(set_time_done), 
        .busy(busy), 
        .o_sec(o_sec), 
        .o_min(o_min), 
        .o_hour(o_hour), 
        .o_date(o_date), 
        .o_month(o_month), 
        .o_year(o_year)
    );

    // Clock Generation (50MHz 기준)
    initial begin
        clk = 0;
        forever #10 clk = ~clk;
    end

    // 현재 시간: 2026-03-10 16:58:57 (BCD 포맷으로 준비)
    wire [7:0] mocked_data;
    assign mocked_data = (shift_reg_in == 8'h81) ? 8'h57 : // READ_SEC   : 57초
                         (shift_reg_in == 8'h83) ? 8'h58 : // READ_MIN   : 58분
                         (shift_reg_in == 8'h85) ? 8'h16 : // READ_HOUR  : 16시
                         (shift_reg_in == 8'h87) ? 8'h10 : // READ_DATE  : 10일
                         (shift_reg_in == 8'h89) ? 8'h03 : // READ_MONTH : 03월
                         (shift_reg_in == 8'h8D) ? 8'h26 : // READ_YEAR  : 26년
                         8'h00;

    // 1. 컨트롤러가 보내는 Command 수신 (SCLK Rising Edge)
    always @(posedge sclk or negedge ce) begin
        if (!ce) begin
            bit_count <= 0;
            shift_reg_in <= 8'h00;
        end else begin
            if (bit_count < 8) begin
                // LSB부터 들어오므로 쉬프트
                shift_reg_in <= {ds1302_data, shift_reg_in[7:1]};
            end
            bit_count <= bit_count + 1;
        end
    end

    // 2. 컨트롤러로 시간 데이터 송신 (SCLK Falling Edge)
    always @(negedge sclk or negedge ce) begin
        if (!ce) begin
            ds1302_data_oe <= 0;
        end else begin
            if (bit_count == 8) begin
                // 8번째 클락 폴링 엣지: 데이터 전송 시작
                ds1302_data_oe <= 1;
                ds1302_data_out <= mocked_data[0]; // LSB 먼저 출력
                shift_reg_out <= {1'b0, mocked_data[7:1]};
            end else if (bit_count > 8 && bit_count < 16) begin
                // 9~15번째 클락 폴링 엣지: 나머지 비트 출력
                ds1302_data_out <= shift_reg_out[0];
                shift_reg_out <= {1'b0, shift_reg_out[7:1]};
            end else if (bit_count == 16) begin
                // 전송 완료 후 High-Z 전환
                ds1302_data_oe <= 0;
            end
        end
    end

    // --- 시뮬레이션 시나리오 ---
    initial begin
        // 초기화
        reset = 1;
        start_trigger = 0;
        write_request = 0;
        i_sec = 0; i_min = 0; i_hour = 0; 
        i_date = 0; i_month = 0; i_year = 0;
        ds1302_data_oe = 0;
        ds1302_data_out = 0;
        
        #100;
        reset = 0; // 리셋 해제
        #100;

        // 시간 읽기 트리거
        @(posedge clk);
        start_trigger = 1;
        @(posedge clk);
        start_trigger = 0;

        // 컨트롤러가 모든 데이터를 읽어올 때까지 대기
        wait (uut.state == 4'd4 && uut.cmd == 8'h8D && uut.w_done);
        #40_000;

        // 결과 출력
        $display("========================================");
        $display("DS1302 Read Simulation Completed!");
        $display("Time Read: 20%d-%02d-%02d %02d:%02d:%02d", 
                  o_year, o_month, o_date, o_hour, o_min, o_sec);
        $display("========================================");

        // 시뮬레이션 종료
        $finish;
    end

endmodule