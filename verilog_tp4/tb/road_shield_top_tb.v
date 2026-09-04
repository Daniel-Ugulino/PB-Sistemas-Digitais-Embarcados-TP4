`timescale 1ns / 1ps

module road_shield_top_tb;

    localparam CLK_HZ     = 100_000;
    localparam GAP_MS     = 1;
    localparam TRIG_US    = 10;
    localparam BLIND_US   = 200;
    localparam WARMUP_MS  = 0;
    localparam TIMEOUT_MS = 20;
    localparam CLK_NS     = 10;

    localparam ECHO_50_CYC = 290;

    reg  clk;
    reg  btn1;
    reg  btn2;
    reg  echo_e;
    reg  echo_c;
    reg  echo_d;
    reg  spi_sck;
    reg  spi_mosi;
    reg  spi_cs_n;

    wire trig_e, trig_c, trig_d;
    wire spi_miso;
    wire number_din, number_clk, number_cs;
    wire arrow_din, arrow_clk, arrow_cs;

    integer erros;

    road_shield_top #(
        .CLK_HZ     (CLK_HZ),
        .GAP_MS     (GAP_MS),
        .TRIG_US    (TRIG_US),
        .BLIND_US   (BLIND_US),
        .WARMUP_MS  (WARMUP_MS),
        .TIMEOUT_MS (TIMEOUT_MS)
    ) dut (
        .clk        (clk),
        .btn1       (btn1),
        .btn2       (btn2),
        .echo_e     (echo_e),
        .echo_c     (echo_c),
        .echo_d     (echo_d),
        .spi_sck    (spi_sck),
        .spi_mosi   (spi_mosi),
        .spi_cs_n   (spi_cs_n),
        .spi_miso   (spi_miso),
        .trig_e     (trig_e),
        .trig_c     (trig_c),
        .trig_d     (trig_d),
        .number_din (number_din),
        .number_clk (number_clk),
        .number_cs  (number_cs),
        .arrow_din  (arrow_din),
        .arrow_clk  (arrow_clk),
        .arrow_cs   (arrow_cs)
    );

    initial clk = 1'b0;
    always #(CLK_NS/2) clk = ~clk;

    task check;
        input cond;
        input [255:0] name;
        begin
            if (cond)
                $display("OK   %0s", name);
            else begin
                $display("FAIL %0s", name);
                erros = erros + 1;
            end
        end
    endtask

    task wait_clk;
        input integer n;
        integer i;
        begin
            for (i = 0; i < n; i = i + 1)
                @(posedge clk);
        end
    endtask

    task wait_trig_fall;
        integer guard;
        begin
            guard = 0;
            while (!trig_e && guard < 50000) begin
                @(posedge clk);
                guard = guard + 1;
            end
            while (trig_e && guard < 50000) begin
                @(posedge clk);
                guard = guard + 1;
            end
        end
    endtask

    task pulse_echo;
        input integer high_cyc;
        integer i;
        begin
            echo_e = 1'b1;
            for (i = 0; i < high_cyc; i = i + 1)
                @(posedge clk);
            echo_e = 1'b0;
        end
    endtask

    task wait_timeout_e;
        integer guard;
        begin
            guard = 0;
            while (guard < 200000 && !dut.timeout_e) begin
                @(posedge clk);
                guard = guard + 1;
            end
        end
    endtask

    task wait_ciclo;
        integer guard;
        begin
            guard = 0;
            while (guard < 400000 && !dut.ciclo_pronto) begin
                @(posedge clk);
                guard = guard + 1;
            end
            wait_clk(2);
        end
    endtask

    initial begin
        erros     = 0;
        btn1      = 1'b0;
        btn2      = 1'b0;
        echo_e    = 1'b0;
        echo_c    = 1'b0;
        echo_d    = 1'b0;
        spi_sck   = 1'b0;
        spi_mosi  = 1'b0;
        spi_cs_n  = 1'b1;

        wait_clk(300);

        check(dut.arrow_on === 1'b0, "1 seta apagada sem eco");

        wait_trig_fall();
        wait_clk(3);
        pulse_echo(ECHO_50_CYC);
        wait_ciclo();
        check(dut.arrow_on === 1'b1, "2 seta acende com objeto a 50cm");
        check(dut.dir_fuga === 2'b11, "2 dir assist tras (C/D sem medida)");

        // Eco longe (~150 cm): alem do dist_free padrao (100 cm)
        wait_trig_fall();
        wait_clk(3);
        pulse_echo(ECHO_50_CYC * 3);
        wait_ciclo();
        check(dut.arrow_on === 1'b0, "3 seta apaga com objeto longe");

        wait_trig_fall();
        wait_timeout_e();
        wait_ciclo();
        check(dut.arrow_on === 1'b0, "4 seta apagada no timeout");

        echo_e = 1'b1;
        wait_clk(500);
        check(dut.arrow_on === 1'b0, "5 seta apagada com echo preso em HIGH");

        if (erros == 0)
            $display("road_shield_top: testes OK");
        else
            $display("road_shield_top: %0d FALHAS", erros);

        $finish;
    end

endmodule
