`timescale 1ns / 1ps

module road_shield_top_speed_tb;

    localparam [7:0] TB_VEL_MAX = 8'd100;

    reg  clk, btn1, btn2;
    reg  spi_sck, spi_mosi, spi_cs_n;
    wire spi_miso;
    wire number_din, number_clk, number_cs;
    wire [7:0] speed;

    integer spi_frames;

    reg [15:0] rx_frame;
    integer    rx_bits;

    road_shield_top_speed #(.CLK_HZ(1000)) dut (
        .clk        (clk),
        .btn1       (btn1),
        .btn2       (btn2),
        .spi_sck    (spi_sck),
        .spi_mosi   (spi_mosi),
        .spi_cs_n   (spi_cs_n),
        .spi_miso   (spi_miso),
        .number_din (number_din),
        .number_clk (number_clk),
        .number_cs  (number_cs)
    );

    assign speed = dut.u_speed.speed;

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        $dumpfile("tb/road_shield_top_speed_tb.vcd");
        $dumpvars(0, road_shield_top_speed_tb);
    end

    always @(negedge number_cs) spi_frames = spi_frames + 1;

    task press;
        input up;
        begin
            if (up) btn1 = 0; else btn2 = 0;
            repeat (20) @(posedge clk);
            btn1 = 1; btn2 = 1;
            repeat (20) @(posedge clk);
        end
    endtask

    task check;
        input [7:0]   expected;
        input [255:0] name;
        begin
            if (speed === expected)
                $display("OK %0s: speed = %0d", name, speed);
            else
                $display("ERROR %0s: esperado %0d, obtido %0d", name, expected, speed);
        end
    endtask

    task get_frame;
        begin
            @(negedge number_cs);
            rx_frame = 0;
            rx_bits  = 0;
            for (i = 15; i >= 0; i = i - 1) begin
                @(posedge number_clk);
                rx_frame[i] = number_din;
                rx_bits     = rx_bits + 1;
            end
        end
    endtask

    task spi_read_byte;
        output [7:0] data;
        integer b;
        begin
            data = 0;
            spi_mosi = 0;
            for (b = 7; b >= 0; b = b - 1) begin
                repeat (4) @(posedge clk);
                spi_sck = 1;
                repeat (4) @(posedge clk);
                data[b] = spi_miso;
                spi_sck = 0;
                repeat (2) @(posedge clk);
            end
        end
    endtask

    task read_speed;
        output [7:0] got_speed;
        reg [7:0] b0, b1, b2, b3, b4, b5, b6, b7;
        begin
            spi_cs_n = 0;
            spi_mosi = 0;
            repeat (8) @(posedge clk);
            spi_read_byte(b0);
            spi_read_byte(b1);
            spi_read_byte(b2);
            spi_read_byte(b3);
            spi_read_byte(b4);
            spi_read_byte(b5);
            spi_read_byte(b6);
            spi_read_byte(b7);
            repeat (8) @(posedge clk);
            spi_cs_n = 1;
            repeat (20) @(posedge clk);
            if (b0 === 8'h02 && b1 === 8'h20 && b7 === 8'h03)
                got_speed = b2;
            else
                got_speed = 8'hFF;
        end
    endtask

    reg [7:0] polled_speed;

    integer k;
    integer i;
    integer spi_found;

    task spi_byte;
        input [7:0] data;
        integer b;
        begin
            for (b = 7; b >= 0; b = b - 1) begin
                spi_mosi = data[b];
                repeat (4) @(posedge clk);
                spi_sck = 1;
                repeat (4) @(posedge clk);
                spi_sck = 0;
                repeat (2) @(posedge clk);
            end
        end
    endtask

    task send_cfg;
        input [7:0] dist_free;
        input [7:0] dist_att;
        input [7:0] vel_max;
        begin
            spi_cs_n = 0;
            repeat (8) @(posedge clk);
            spi_byte(8'h02);
            spi_byte(8'h10);
            spi_byte(dist_free);
            spi_byte(dist_att);
            spi_byte(vel_max);
            spi_byte(8'h03);
            repeat (8) @(posedge clk);
            spi_cs_n = 1;
            repeat (20) @(posedge clk);
        end
    endtask

    initial begin
        spi_frames = 0;
        btn1 = 1; btn2 = 1;
        spi_sck = 0; spi_mosi = 0; spi_cs_n = 1;
        repeat (300) @(posedge clk);

        // Config inicial via SPI (vel_max vem do Pi, nao de parametro fixo)
        send_cfg(8'd100, 8'd50, TB_VEL_MAX);

        // Teste 1: incremento basico
        press(1);
        check(8'd5, "incremento basico");

        // Teste 2: loop ate 120, nao pode passar de vel_max do SPI
        for (k = 0; k < 24; k = k + 1) begin
            press(1);
            if (speed > TB_VEL_MAX)
                $display("ERROR saturacao iter %0d: speed=%0d > MAX=%0d", k, speed, TB_VEL_MAX);
        end
        check(TB_VEL_MAX, "Nao ultrapasso max speed");

        // Teste 3: tentar reduzir até 0 (nao fica negativo)
        for (k = 0; k < 25; k = k + 1) press(0);
        check(8'd0, "underflow em zero");

        // Teste 4: display SPI mostra speed = 15
        for (k = 0; k < 3; k = k + 1) press(1);
        check(8'd15, "speed para teste SPI");

        spi_found = 0;
        for (k = 0; k < 12; k = k + 1) begin
            get_frame();
            if (rx_frame === (16'h0100 + (15 % 10)) && rx_bits === 16)
                spi_found = 1;
        end
        if (spi_found)
            $display("OK SPI unidade: 0x%04h", 16'h0100 + (15 % 10));
        else
            $display("FAIL SPI unidade: quadro 0x%04h nao encontrado", 16'h0100 + (15 % 10));

        // Teste 5: display continua ativo
        repeat (20000) @(posedge clk);
        if (spi_frames >= 10)
            $display("OK display ativo (%0d quadros)", spi_frames);
        else
            $display("FAIL display parado (%0d quadros)", spi_frames);

        // Teste 6: Pi envia dist_free, dist_att e vel_max via SPI
        send_cfg(8'd80, 8'd40, 8'd60);
        if (dut.u_cfg.dist_free === 8'd80 &&
            dut.u_cfg.dist_att  === 8'd40 &&
            dut.u_cfg.vel_max   === 8'd60)
            $display("OK config SPI: livre=%0d att=%0d vel=%0d",
                     dut.u_cfg.dist_free, dut.u_cfg.dist_att, dut.u_cfg.vel_max);
        else
            $display("FAIL config SPI: livre=%0d att=%0d vel=%0d",
                     dut.u_cfg.dist_free, dut.u_cfg.dist_att, dut.u_cfg.vel_max);

        // Teste 7: Tang envia velocidade atual para o Pi
        read_speed(polled_speed);
        if (polled_speed === 8'd15)
            $display("OK speed TX: vel=%0d", polled_speed);
        else
            $display("FAIL speed TX: vel=%0d (esperado 15)", polled_speed);

        $finish;
    end

endmodule
