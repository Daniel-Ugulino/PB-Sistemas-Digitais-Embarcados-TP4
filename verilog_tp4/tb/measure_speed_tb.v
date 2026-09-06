`timescale 1ns / 1ps

module measure_speed_tb;

    localparam CLK_HZ = 100_000;
    localparam CLK_NS = 10;
    localparam MS_CYC = CLK_HZ / 1000;

    reg  clk;
    reg  rst;
    reg  amostra;
    reg  [7:0] dist;
    reg  [7:0] vel_car;
    wire [7:0] dist_atual;
    wire [7:0] vel;

    integer erros;

    measure_speed #(.CLK_HZ(CLK_HZ)) dut (
        .clk            (clk),
        .rst            (rst),
        .amostra_valida (amostra),
        .distancia_cm   (dist),
        .vel_atual      (vel_car),
        .dist_atual     (dist_atual),
        .vel_obstaculo  (vel)
    );

    initial clk = 1'b0;
    always #(CLK_NS/2) clk = ~clk;

    task wait_clk;
        input integer n;
        integer i;
        begin
            for (i = 0; i < n; i = i + 1)
                @(posedge clk);
        end
    endtask

    task wait_ms;
        input integer n;
        begin
            wait_clk(n * MS_CYC);
        end
    endtask

    task push;
        input [7:0] d;
        begin
            @(negedge clk);
            dist    = d;
            amostra = 1'b1;
            @(negedge clk);
            amostra = 1'b0;
            @(posedge clk);
        end
    endtask

    task check;
        input [7:0] exp;
        input [255:0] name;
        begin
            if (vel === exp)
                $display("OK   %0s: vel=%0d", name, vel);
            else begin
                $display("ERROR %0s: vel=%0d (exp %0d)", name, vel, exp);
                erros = erros + 1;
            end
        end
    endtask

    initial begin
        $dumpfile("tb/measure_speed_tb.vcd");
        $dumpvars(0, measure_speed_tb);

        erros   = 0;
        rst     = 1'b1;
        amostra = 1'b0;
        dist    = 8'd0;
        vel_car = 8'd36;

        wait_clk(5);
        rst = 1'b0;
        wait_clk(2);

        // 1. Primeira amostra: janela vazia → vel_atual
        push(8'd80);
        check(8'd36, "1 primeira amostra = vel_atual");

        // 2. Terceira amostra: ainda em warmup
        wait_ms(90);
        push(8'd80);
        wait_ms(90);
        push(8'd80);
        check(8'd36, "2 terceira amostra = vel_atual");

        // 3. Quarta (AMOSTRAS_MIN): vao constante → vel_obstaculo = vel_atual
        wait_ms(90);
        push(8'd80);
        check(8'd36, "3 vao constante, v_obs=36");

        // 4. Fecha 80 cm sobre ~360 ms (hist[0] → agora)
        //    v_rel = -80*36/360 = -8  →  |36-8|=28
        wait_ms(90);
        push(8'd0);
        check(8'd28, "4 janela BRAM, vel_obs=28");

        if (erros == 0)
            $display("measure_speed: 4 testes OK");
        else
            $display("measure_speed: %0d FALHAS", erros);

        $finish;
    end

endmodule
