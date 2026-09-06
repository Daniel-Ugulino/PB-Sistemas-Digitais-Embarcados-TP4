`timescale 1ns / 1ps

// Botoes ativos em baixo. Amostra a cada CLK_HZ/100 ciclos.
// Clique = borda de pressionamento (±5 km/h).
// Teto = max_speed (ou 120 se max_speed=0). Nao desce abaixo de 0.

module speed_control_tb;

    localparam CLK_HZ     = 1_000;
    localparam CLK_NS     = 10;
    localparam SAMPLE_MAX = CLK_HZ / 100;

    reg        clk;
    reg        btn1;
    reg        btn2;
    reg  [7:0] max_speed;
    wire [7:0] speed;

    integer erros;

    speed_control #(.CLK_HZ(CLK_HZ)) dut (
        .clk       (clk),
        .btn1      (btn1),
        .btn2      (btn2),
        .max_speed (max_speed),
        .speed     (speed)
    );

    initial clk = 1'b0;
    always #(CLK_NS/2) clk = ~clk;

    task check;
        input [7:0]   exp;
        input [255:0] name;
        begin
            if (speed === exp)
                $display("OK   %0s  speed=%0d", name, speed);
            else begin
                $display("ERROR %0s  speed=%0d (exp %0d)", name, speed, exp);
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

    task wait_sample;
        begin
            wait_clk(SAMPLE_MAX + 2);
        end
    endtask

    task press_up;
        begin
            btn1 = 1'b0;
            wait_sample();
            btn1 = 1'b1;
            wait_sample();
        end
    endtask

    task press_down;
        begin
            btn2 = 1'b0;
            wait_sample();
            btn2 = 1'b1;
            wait_sample();
        end
    endtask

    initial begin
        $dumpfile("tb/speed_control_tb.vcd");
        $dumpvars(0, speed_control_tb);

        erros     = 0;
        btn1      = 1'b1;
        btn2      = 1'b1;
        max_speed = 8'd15;

        wait_sample();
        check(8'd0, "1 apos reset speed=0");

        // 2. Um clique em btn1 → +5
        press_up();
        check(8'd5, "2 clique btn1");

        // 3. Mais cliques ate o teto 15; o extra nao passa
        press_up();
        press_up();
        check(8'd15, "3 satura no teto");
        press_up();
        check(8'd15, "3 clique extra permanece 15");

        // 4. btn2 desce; abaixo de 5 satura em 0
        press_down();
        check(8'd10, "4 clique btn2");
        press_down();
        press_down();
        press_down();
        check(8'd0, "4 nao desce abaixo de 0");

        if (erros == 0)
            $display("speed_control: 4 testes OK");
        else
            $display("speed_control: %0d FALHAS", erros);

        $finish;
    end

endmodule
