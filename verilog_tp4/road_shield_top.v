// Enlace com o Raspberry Pi: SPI modo 0, Pi = master, Tang Nano = slave.
//   Pi escreve  -> pacote de configuracao (config_rx)
//   Pi le       -> pacote de telemetria (config_tx)
//
// Ligacao (Pi SPI0 -> Tang Nano):
//   GPIO11 SCLK -> spi_sck    GPIO10 MOSI -> spi_mosi
//   GPIO9  MISO <- spi_miso   GPIO8  CE0  -> spi_cs_n    GND comum

module road_shield_top #(
    parameter CLK_HZ     = 27_000_000,
    parameter GAP_MS     = 60,
    parameter TRIG_US    = 10,
    parameter TIMEOUT_MS = 30
) (
    input  wire       clk,
    input  wire       btn1,
    input  wire       btn2,
    input  wire       echo_e,
    input  wire       echo_c,
    input  wire       echo_d,
    input  wire       spi_sck,
    input  wire       spi_mosi,
    input  wire       spi_cs_n,
    output wire       spi_miso,
    output wire       trig_e,
    output wire       trig_c,
    output wire       trig_d,
    output wire [7:0] dist_e,
    output wire [7:0] dist_c,
    output wire [7:0] dist_d,
    output wire signed [7:0] vel_e,
    output wire signed [7:0] vel_c,
    output wire signed [7:0] vel_d,
    output wire [7:0] vel_rec,
    output wire [1:0] dir_fuga,
    output wire       ciclo_pronto,
    output wire [3:0] estado_fsm,
    output wire       cfg_valida,
    output wire       number_din,
    output wire       number_clk,
    output wire       number_cs,
    output wire       arrow_din,
    output wire       arrow_clk,
    output wire       arrow_cs
);

    // Reset ao ligar (igual road_shield_top_speed): 255 ciclos, sem pino
    reg [7:0] por_cnt = 8'd0;
    wire      rst     = (por_cnt != 8'hff);

    always @(posedge clk) begin
        if (rst)
            por_cnt <= por_cnt + 8'd1;
    end

    wire [7:0] rx_byte;
    wire       byte_valido;
    wire       quadro_ativo;
    wire       cs_desce;
    wire       quadro_fim;
    wire [7:0] tx_byte;

    wire [7:0] cfg_dist_free;
    wire [7:0] cfg_dist_att;
    wire [7:0] cfg_vel_max;
    wire [7:0] vel_atual;

    road_sensores #(
        .CLK_HZ(CLK_HZ),
        .GAP_MS(GAP_MS),
        .TRIG_US(TRIG_US),
        .TIMEOUT_MS(TIMEOUT_MS)
    ) sensores (
        .clk           (clk),
        .rst           (rst),
        .iniciar       (1'b1),
        .echo_e        (echo_e),
        .echo_c        (echo_c),
        .echo_d        (echo_d),
        .trig_e        (trig_e),
        .trig_c        (trig_c),
        .trig_d        (trig_d),
        .dist_e        (dist_e),
        .dist_c        (dist_c),
        .dist_d        (dist_d),
        .ciclo_pronto  (ciclo_pronto),
        .estado_fsm    (estado_fsm),
        .vel_e         (vel_e),
        .vel_c         (vel_c),
        .vel_d         (vel_d)
    );

    spi_slave u_spi (
        .clk          (clk),
        .rst          (rst),
        .sck          (spi_sck),
        .mosi         (spi_mosi),
        .cs_n         (spi_cs_n),
        .miso         (spi_miso),
        .rx_byte      (rx_byte),
        .byte_valido  (byte_valido),
        .tx_byte      (tx_byte),
        .quadro_ativo (quadro_ativo),
        .cs_desce     (cs_desce),
        .quadro_fim   (quadro_fim)
    );

    config_rx u_cfg (
        .clk         (clk),
        .rst         (rst),
        .rx_byte     (rx_byte),
        .byte_valido (byte_valido),
        .quadro_fim  (quadro_fim),
        .dist_free   (cfg_dist_free),
        .dist_att    (cfg_dist_att),
        .vel_max     (cfg_vel_max),
        .cfg_valid   (cfg_valida)
    );

    speed_control #(.CLK_HZ(CLK_HZ)) u_speed (
        .clk       (clk),
        .btn1      (btn1),
        .btn2      (btn2),
        .max_speed (cfg_vel_max),
        .speed     (vel_atual)
    );

    assist_control u_dec (
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

    config_tx u_config_tx (
        .clk          (clk),
        .rst          (rst),
        .speed        (vel_atual),
        .dist_e       (dist_e),
        .dist_c       (dist_c),
        .dist_d       (dist_d),
        .dir          (dir_fuga),
        .cs_desce     (cs_desce),
        .quadro_ativo (quadro_ativo),
        .rx_byte      (rx_byte),
        .byte_valido  (byte_valido),
        .quadro_fim   (quadro_fim),
        .tx_byte      (tx_byte)
    );

    // Esquerda: velocidade atual | Direita: velocidade recomendada
    number_control u_display (
        .clk        (clk),
        .rst_n      (~rst),
        .value_a    ({6'd0, vel_atual}),
        .value_b    ({6'd0, vel_rec}),
        .number_din (number_din),
        .number_clk (number_clk),
        .number_cs  (number_cs)
    );

    arrow_display u_arrow (
        .clk        (clk),
        .rst_n      (~rst),
        .direction  (dir_fuga),
        .arrow_din  (arrow_din),
        .arrow_clk  (arrow_clk),
        .arrow_cs   (arrow_cs)
    );

endmodule
