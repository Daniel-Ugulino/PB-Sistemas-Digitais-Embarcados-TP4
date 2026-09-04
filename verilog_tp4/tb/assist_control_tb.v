`timescale 1ns / 1ps

module assist_control_tb;

    localparam [7:0] DIST_FREE = 8'd100;
    localparam [7:0] DIST_ATT  = 8'd50;
    localparam [7:0] VEL_MAX   = 8'd120;
    localparam [7:0] VEL_NOW   = 8'd80;

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

    task apply;
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
                $display("OK   %0s: dir=%0d vel_rec=%0d", name, dir_fuga, vel_rec);
            else begin
                $display("FAIL %0s: dir=%0d (exp %0d) vel_rec=%0d (exp %0d)",
                         name, dir_fuga, exp_dir, vel_rec, exp_vel);
                erros = erros + 1;
            end
        end
    endtask

    initial begin
        $dumpfile("tb/assist_control_tb.vcd");
        $dumpvars(0, assist_control_tb);

        erros = 0;
        cfg_dist_free = DIST_FREE;
        cfg_dist_att  = DIST_ATT;
        cfg_vel_max   = VEL_MAX;
        vel_atual     = VEL_NOW;

        // 1. Centro livre, obstaculos acompanham o carro
        apply(8'd120, 8'd140, 8'd110, 8'd80, 8'd80, 8'd80);
        check(FRENTE, 8'd80, "1 livre C, sem fechar");

        // 2. Centro atencao, esquerda livre
        apply(8'd130, 8'd70, 8'd40, 8'd80, 8'd80, 8'd80);
        check(ESQUERDA, 8'd60, "2 C atencao, E livre");

        // 3. Ninguem livre; C e E atencao
        apply(8'd60, 8'd70, 8'd40, 8'd80, 8'd80, 8'd80);
        check(FRENTE, 8'd60, "3 so atencao, prefere C");

        // 4. C livre mas 18 km/h mais lento; E atencao segura
        apply(8'd80, 8'd150, 8'd40, 8'd80, 8'd62, 8'd80);
        check(ESQUERDA, 8'd80, "4 veto C (fecha 18), E atencao");

        // 5. Tudo critico
        apply(8'd25, 8'd25, 8'd25, 8'd80, 8'd80, 8'd80);
        check(TRAS, 8'd40, "5 tudo critico");

        // 6. Tudo atencao, D fecha
        apply(8'd70, 8'd65, 8'd55, 8'd80, 8'd80, 8'd55);
        check(FRENTE, 8'd60, "6 atencao, D vetada");

        // 7. So D livre
        apply(8'd30, 8'd20, 8'd120, 8'd60, 8'd50, 8'd80);
        check(DIREITA, 8'd40, "7 so D livre");

        // 8. vel_obs=vel_atual (warmup do measure_speed): seguro
        apply(8'd40, 8'd140, 8'd40, 8'd80, 8'd80, 8'd80);
        check(FRENTE, 8'd80, "8 C livre, acompanha");

        // 9. Limiar: fecha 9 km/h ainda seguro
        apply(8'd40, 8'd140, 8'd40, 8'd80, 8'd71, 8'd80);
        check(FRENTE, 8'd80, "9 vel_c=71 ainda segura");

        // 10. Limiar: fecha 10 km/h veta o centro
        apply(8'd80, 8'd140, 8'd40, 8'd80, 8'd70, 8'd80);
        check(ESQUERDA, 8'd80, "10 vel_c=70 veta C, E atencao");

        // 11. vel_atual acima do teto do Pi
        vel_atual = 8'd200;
        apply(8'd120, 8'd140, 8'd110, 8'd200, 8'd200, 8'd200);
        check(FRENTE, VEL_MAX, "11 base = min(atual, vel_max)");

        // 12. Critico com atual < reducao → satura em 0
        vel_atual = 8'd30;
        apply(8'd20, 8'd20, 8'd20, 8'd30, 8'd30, 8'd30);
        check(TRAS, 8'd0, "12 30-40 satura em 0");

        if (erros == 0)
            $display("assist_control: %0d testes OK", 12);
        else
            $display("assist_control: %0d FALHAS", erros);

        $finish;
    end

endmodule
