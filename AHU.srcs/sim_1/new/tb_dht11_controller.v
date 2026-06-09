`timescale 1ns / 1ps

module tb_dht11_controller;

    // Inputs
    reg clk;
    reg reset;
    reg start_trigger;

    // Outputs
    wire [7:0] hum_int;
    wire [7:0] hum_dec;
    wire [7:0] tem_int;
    wire [7:0] tem_dec;

    // Inout
    wire dht11_data;

    // 가상의 DHT11 제어용 신호
    reg tb_oe;
    reg tb_out;
    integer i;

    dht_controller uut (
        .clk(clk),
        .reset(reset),
        .start_trigger(start_trigger),
        .dht11_data(dht11_data),
        .hum_int(hum_int),
        .hum_dec(hum_dec),
        .tem_int(tem_int),
        .tem_dec(tem_dec)
    );

    // 1-Wire 통신을 위한 Pull-up 저항 모사 (아무도 출력을 내지 않을 때 High 유지)
    pullup(dht11_data);

    // 테스트벤치에서 dht11_data로 값을 보낼 때 사용
    assign dht11_data = tb_oe ? tb_out : 1'bz;

    // 100MHz Clock Generation (주기 10ns)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // 테스트 시나리오
    initial begin
        // 초기화
        reset = 1;
        start_trigger = 0;
        
        #100;
        reset = 0;
        #100;

        // 시작 신호 발생 (1 클럭)
        @(posedge clk);
        start_trigger = 1;
        @(posedge clk);
        start_trigger = 0;

        // 통신이 완료되어 UUT가 IDLE(0) 상태로 돌아올 때까지 대기
        wait(uut.u_dht11_main_logic.state == 4'd7); // CHECK_DATA state
        wait(uut.u_dht11_main_logic.state == 4'd0); // IDLE state로 복귀
        
        #1000;

        // 결과 출력
        $display("========================================");
        $display("DHT11 Read Simulation Completed!");
        $display("Temperature : %d.%d C", tem_int, tem_dec);
        $display("Humidity    : %d.%d %%", hum_int, hum_dec);
        $display("========================================");

        $finish;
    end

    // 가상 DHT11 센서 동작 로직 (Start Signal 감지 후 데이터 송신)
    // 보낼 데이터: 온도 25.0도, 습도 60.0% -> Checksum: 25 + 0 + 60 + 0 = 85
    // 작성하신 코드 기준 mapping: {tem_int, tem_dec, hum_int, hum_dec, checksum}
    reg [39:0] dht11_mock_data = {8'd85, 8'd0, 8'd60, 8'd0, 8'd25};

    initial begin
        tb_oe = 0;
        tb_out = 0;

        // 1. 마스터가 18ms 동안 Low로 당기는 것을 기다림
        wait(dht11_data === 1'b0);
        
        // 2. 마스터가 라인을 놓아서(Pull-up) 다시 High가 되는 시점을 기다림
        wait(dht11_data === 1'b1);

        // 마스터가 High로 놓은 뒤 약 20us 대기
        #20_000;

        // 3. 센서 응답 신호: 80us Low -> 80us High
        tb_oe = 1; tb_out = 0; #80_000;
        tb_out = 1; #80_000;

        // 4. 40비트 데이터 전송 로직
        for (i = 0; i < 40; i = i + 1) begin
            // 각 데이터 비트 시작: 50us Low
            tb_out = 0; #50_000;

            // 데이터 비트 값에 따른 High 유지 시간
            tb_out = 1;
            if (dht11_mock_data[i] == 1'b1)
                #70_000; // '1'일 경우 70us 유지
            else
                #28_000; // '0'일 경우 28us 유지 (작성하신 50us threshold보다 짧게)
        end

        // 마지막 Bit Low로 당기기
        tb_out = 0; #50_000;
        

        // 5. 전송 완료 후 Bus Release
        tb_oe = 0; 
    end

endmodule