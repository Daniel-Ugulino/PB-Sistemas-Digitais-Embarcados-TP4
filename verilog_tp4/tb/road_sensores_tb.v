`timescale 1ns / 1ps

// Ciclo E → C → D do road_sensors, com clock acelerado (100 kHz).
// 1. Eco no E ~50 cm
// 2. C sem eco (timeout)
// 3. D com echo preso em 1 (timeout)
// 4. Segundo ciclo: E de novo ~50 cm

module road_sensores_tb;

    localparam CLK_HZ     = 100_000;
    localparam GAP_MS     = 1;
    localparam TRIG_US    = 10;
    localparam BLIND_US   = 200;
    localparam WARMUP_MS  = 0;
    localparam TIMEOUT_MS = 5;
    localparam CLK_NS     = 10;

    // 50 cm × 58 us/cm = 2900 us. 1 clk = 10 us → 290 ciclos
    localparam ECHO_50_CYC = 290;

    localparam F_MED_C = 4'd3;

    reg  clk;
    reg  rst;
    reg  iniciar;
    reg  echo_e, echo_c, echo_d;

    wire trig_e, trig_c, trig_d;
    wire [7:0] dist_e, dist_c, dist_d;
    wire valid_e, valid_c, valid_d;
    wire ciclo_pronto;
    wire [3:0] estado_fsm;
    wire [7:0] vel_e, vel_c, vel_d;

    integer erros;
    integer visto;

    road_sensors #(
        .CLK_HZ     (CLK_HZ),
        .GAP_MS     (GAP_MS),
        .TRIG_US    (TRIG_US),
        .BLIND_US   (BLIND_US),
        .WARMUP_MS  (WARMUP_MS),
        .TIMEOUT_MS (TIMEOUT_MS)
    ) dut (
        .clk          (clk),
        .rst          (rst),
        .iniciar      (iniciar),
        .vel_atual    (8'd0),
        .echo_e       (echo_e),
        .echo_c       (echo_c),
        .echo_d       (echo_d),
        .trig_e       (trig_e),
        .trig_c       (trig_c),
        .trig_d       (trig_d),
        .dist_e       (dist_e),
        .dist_c       (dist_c),
        .dist_d       (dist_d),
        .valid_e      (valid_e),
        .valid_c      (valid_c),
        .valid_d      (valid_d),
        .ciclo_pronto (ciclo_pronto),
        .estado_fsm   (estado_fsm),
        .dist_atual_e (),
        .dist_atual_c (),
        .dist_atual_d (),
        .vel_e        (vel_e),
        .vel_c        (vel_c),
        .vel_d        (vel_d)
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
                $display("ERROR %0s", name);
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

    // Espera o pulso TRIG no fio (nao passar o sinal como input —
    // isso copia o valor e o while nunca ve a mudanca).
    task wait_trig_e;
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

    task wait_trig_c;
        integer guard;
        begin
            guard = 0;
            while (!trig_c && guard < 50000) begin
                @(posedge clk);
                guard = guard + 1;
            end
            while (trig_c && guard < 50000) begin
                @(posedge clk);
                guard = guard + 1;
            end
        end
    endtask

    task wait_trig_d;
        integer guard;
        begin
            guard = 0;
            while (!trig_d && guard < 50000) begin
                @(posedge clk);
                guard = guard + 1;
            end
            while (trig_d && guard < 50000) begin
                @(posedge clk);
                guard = guard + 1;
            end
        end
    endtask

    task pulse_echo_e;
        input integer n;
        integer i;
        begin
            echo_e = 1'b1;
            for (i = 0; i < n; i = i + 1)
                @(posedge clk);
            echo_e = 1'b0;
        end
    endtask

    task wait_valid_e;
        output integer seen;
        integer guard;
        begin
            seen  = 0;
            guard = 0;
            while (guard < 200000 && !valid_e) begin
                @(posedge clk);
                guard = guard + 1;
            end
            if (valid_e)
                seen = 1;
        end
    endtask

    initial begin
        $dumpfile("tb/road_sensores_tb.vcd");
        $dumpvars(0, road_sensores_tb);

        erros   = 0;
        rst     = 1'b1;
        iniciar = 1'b0;
        echo_e  = 1'b0;
        echo_c  = 1'b0;
        echo_d  = 1'b0;

        wait_clk(5);
        rst = 1'b0;
        wait_clk(2);
        iniciar = 1'b1;

        // 1. Sensor E: eco de 50 cm
        wait_trig_e();
        wait_clk(3);
        pulse_echo_e(ECHO_50_CYC);
        wait_valid_e(visto);
        check(visto === 1, "1 valid_e apos eco 50 cm");
        check(dist_e >= 8'd47 && dist_e <= 8'd53, "1 dist_e ~50 cm");

        // 2. Sensor C: sem eco → timeout, dist/vel ficam 0
        wait_trig_c();
        visto = 0;
        begin : timeout_c
            integer g;
            g = 0;
            while (g < 200000 && estado_fsm == F_MED_C) begin
                @(posedge clk);
                g = g + 1;
                if (valid_c)
                    visto = 1;
            end
        end
        check(visto === 0, "2 valid_c silencioso no timeout");
        check(dist_c === 8'd0, "2 dist_c permanece 0");
        check(vel_c === 8'd0, "2 vel_c permanece 0");

        // 3. Sensor D: echo preso em 1 → timeout, dist_e nao muda
        wait_trig_d();
        echo_d = 1'b1;
        visto = 0;
        begin : timeout_d
            integer g;
            g = 0;
            while (g < 200000 && !ciclo_pronto) begin
                @(posedge clk);
                g = g + 1;
                if (valid_d)
                    visto = 1;
            end
        end
        echo_d = 1'b0;
        check(visto === 0, "3 valid_d silencioso com echo preso");
        check(dist_d === 8'd0, "3 dist_d permanece 0");
        check(dist_e >= 8'd47 && dist_e <= 8'd53, "3 dist_e ainda ~50 cm");

        // 4. Segundo ciclo: E de novo ~50 cm
        wait_trig_e();
        wait_clk(3);
        pulse_echo_e(ECHO_50_CYC);
        wait_valid_e(visto);
        check(visto === 1, "4 segundo valid_e");
        check(dist_e >= 8'd47 && dist_e <= 8'd53, "4 dist_e ainda ~50 cm");

        if (erros == 0)
            $display("road_sensores: testes OK");
        else
            $display("road_sensores: %0d FALHAS", erros);

        $finish;
    end

endmodule
