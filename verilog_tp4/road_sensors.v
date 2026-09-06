// Top: FSM dos 3 sensores + distancia/velocidade por canal (E, C, D)

module road_sensors #(
    parameter CLK_HZ      = 27_000_000,
    parameter GAP_MS      = 60,
    parameter TRIG_US     = 20,
    parameter BLIND_US    = 300,
    parameter WARMUP_MS   = 50,
    parameter TIMEOUT_MS  = 30
) (
    input  wire       clk,
    input  wire       rst,
    input  wire       iniciar,
    input  wire [7:0] vel_atual,
    input  wire       echo_e,
    input  wire       echo_c,
    input  wire       echo_d,
    output wire       trig_e,
    output wire       trig_c,
    output wire       trig_d,
    output wire [7:0] dist_e,
    output wire [7:0] dist_c,
    output wire [7:0] dist_d,
    output wire       valid_e,
    output wire       valid_c,
    output wire       valid_d,
    output wire       ciclo_pronto,
    output wire       timeout_e,
    output wire [3:0] estado_fsm,
    output wire [7:0] dist_atual_e,
    output wire [7:0] dist_atual_c,
    output wire [7:0] dist_atual_d,
    output wire [7:0] vel_e,
    output wire [7:0] vel_c,
    output wire [7:0] vel_d
);

    wire valid_e_p;
    wire valid_c_p;
    wire valid_d_p;

    fsm_sensors #(
        .CLK_HZ(CLK_HZ),
        .GAP_MS(GAP_MS),
        .TRIG_US(TRIG_US),
        .BLIND_US(BLIND_US),
        .WARMUP_MS(WARMUP_MS),
        .TIMEOUT_MS(TIMEOUT_MS)
    ) fsm (
        .clk          (clk),
        .rst          (rst),
        .iniciar      (iniciar),
        .echo_e       (echo_e),
        .echo_c       (echo_c),
        .echo_d       (echo_d),
        .trig_e       (trig_e),
        .trig_c       (trig_c),
        .trig_d       (trig_d),
        .dist_e       (dist_e),
        .dist_c       (dist_c),
        .dist_d       (dist_d),
        .valid_e      (valid_e_p),
        .valid_c      (valid_c_p),
        .valid_d      (valid_d_p),
        .ciclo_pronto (ciclo_pronto),
        .timeout_e    (timeout_e),
        .estado_fsm   (estado_fsm)
    );

    assign valid_e = valid_e_p;
    assign valid_c = valid_c_p;
    assign valid_d = valid_d_p;

    measure_speed #(.CLK_HZ(CLK_HZ)) vel_mod_e (
        .clk            (clk),
        .rst            (rst),
        .amostra_valida (valid_e_p),
        .distancia_cm   (dist_e),
        .vel_atual      (vel_atual),
        .dist_atual     (dist_atual_e),
        .vel_obstaculo  (vel_e)
    );

    measure_speed #(.CLK_HZ(CLK_HZ)) vel_mod_c (
        .clk            (clk),
        .rst            (rst),
        .amostra_valida (valid_c_p),
        .distancia_cm   (dist_c),
        .vel_atual      (vel_atual),
        .dist_atual     (dist_atual_c),
        .vel_obstaculo  (vel_c)
    );

    measure_speed #(.CLK_HZ(CLK_HZ)) vel_mod_d (
        .clk            (clk),
        .rst            (rst),
        .amostra_valida (valid_d_p),
        .distancia_cm   (dist_d),
        .vel_atual      (vel_atual),
        .dist_atual     (dist_atual_d),
        .vel_obstaculo  (vel_d)
    );

endmodule
