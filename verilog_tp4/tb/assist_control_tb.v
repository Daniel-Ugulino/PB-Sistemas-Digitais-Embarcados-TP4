`timescale 1ns / 1ps

// Quatro casos do assistente:
//   livre  > 100 cm    atencao  50–100 cm    critico  < 50 cm
//   vel_atual = 80     vel_max = 120
//   atencao → −20 km/h    critico → −40 km/h

module assist_control_tb;

    localparam [1:0] FRENTE   = 2'b00;
    localparam [1:0] ESQUERDA = 2'b01;
    localparam [1:0] DIREITA  = 2'b10;
    localparam [1:0] TRAS     = 2'b11;

    reg  [7:0] dist_e, dist_c, dist_d;
    reg  [7:0] vel_e, vel_c, vel_d;
    reg  [7:0] vel_atual;
    reg  [7:0] cfg_dist_free, cfg_dist_att, cfg_vel_max;
    wire [7:0] vel_rec;
    wire [1:0] dir_fuga;

    integer erros;

    assist_control dut (
        .dist_e        (dist_e),
        .dist_c        (dist_c),
        .dist_d        (dist_d),
        .vel_e         (vel_e),
        .vel_c         (vel_c),
        .vel_d         (vel_d),
        .vel_atual     (vel_atual),
        .cfg_dist_free (cfg_dist_free),
        .cfg_dist_att  (cfg_dist_att),
        .cfg_vel_max   (cfg_vel_max),
        .vel_rec       (vel_rec),
        .dir_fuga      (dir_fuga)
    );

    task test;
        input [7:0] e, c, d;
        input [7:0] ve, vc, vd;
        begin
            dist_e = e; dist_c = c; dist_d = d;
            vel_e  = ve; vel_c = vc; vel_d = vd;
            #1;
        end
    endtask

    task check;
        input [1:0]   exp_dir;
        input [7:0]   exp_vel;
        input [255:0] name;
        begin
            if (dir_fuga === exp_dir && vel_rec === exp_vel)
                $display("OK   %0s  dir=%0d vel_rec=%0d", name, dir_fuga, vel_rec);
            else begin
                $display("ERROR %0s  dir=%0d (exp %0d) vel_rec=%0d (exp %0d)",
                         name, dir_fuga, exp_dir, vel_rec, exp_vel);
                erros = erros + 1;
            end
        end
    endtask

    initial begin
        $dumpfile("tb/assist_control_tb.vcd");
        $dumpvars(0, assist_control_tb);

        erros         = 0;
        cfg_dist_free = 8'd100;
        cfg_dist_att  = 8'd50;
        cfg_vel_max   = 8'd120;
        vel_atual     = 8'd80;

        // 1. Centro livre, obstaculos acompanham o carro → segue, sem reduzir
        test(8'd120, 8'd140, 8'd110, 8'd80, 8'd80, 8'd80);
        check(FRENTE, 8'd80, "1 centro livre");

        // 2. Centro em atencao, esquerda livre → foge para E, −20 km/h
        test(8'd130, 8'd70, 8'd40, 8'd80, 8'd80, 8'd80);
        check(ESQUERDA, 8'd60, "2 atencao no centro, foge E");

        // 3. Tres sensores criticos → recua, −40 km/h
        test(8'd25, 8'd25, 8'd25, 8'd80, 8'd80, 8'd80);
        check(TRAS, 8'd40, "3 tudo critico, recua");

        // 4. So a direita livre (C critico) → foge para D, −40 km/h
        test(8'd30, 8'd20, 8'd120, 8'd60, 8'd50, 8'd80);
        check(DIREITA, 8'd40, "4 so direita livre");

        if (erros == 0)
            $display("assist_control: 4 testes OK");
        else
            $display("assist_control: %0d FALHAS", erros);

        $finish;
    end

endmodule
