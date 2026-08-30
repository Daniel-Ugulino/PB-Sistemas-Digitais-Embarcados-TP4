module road_shield_top_speed #(
    parameter CLK_HZ             = 27_000_000,
    parameter [7:0] DIST_FREE_INIT = 8'd100,
    parameter [7:0] DIST_ATT_INIT  = 8'd50,
    parameter [7:0] VEL_MAX_INIT   = 8'd120
) (
    input  wire clk,
    input  wire btn1,
    input  wire btn2,
    input  wire spi_sck,
    input  wire spi_mosi,
    input  wire spi_cs_n,
    output wire spi_miso,
    output wire number_din,
    output wire number_clk,
    output wire number_cs
);
    reg [7:0] por_cnt = 8'd0;
    wire      rst     = (por_cnt != 8'hff);

    always @(posedge clk) begin
        if (rst)
            por_cnt <= por_cnt + 8'd1;
    end

    wire [7:0] speed;
    wire [7:0] rx_byte;
    wire [7:0] tx_byte;
    wire       byte_valido;
    wire       quadro_fim;
    wire       quadro_ativo;
    wire       cs_desce;
    wire [7:0] dist_free;
    wire [7:0] dist_att;
    wire [7:0] vel_max;

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

    config_tx u_config_tx (
        .clk          (clk),
        .rst          (rst),
        .speed        (speed),
        .dist_e       (8'd0),
        .dist_c       (8'd0),
        .dist_d       (8'd0),
        .dir          (2'b00),
        .cs_desce     (cs_desce),
        .quadro_ativo (quadro_ativo),
        .rx_byte      (rx_byte),
        .byte_valido  (byte_valido),
        .quadro_fim   (quadro_fim),
        .tx_byte      (tx_byte)
    );

    config_rx #(
        .DIST_FREE_INIT (DIST_FREE_INIT),
        .DIST_ATT_INIT  (DIST_ATT_INIT),
        .VEL_MAX_INIT   (VEL_MAX_INIT)
    ) u_cfg (
        .clk         (clk),
        .rst         (rst),
        .rx_byte     (rx_byte),
        .byte_valido (byte_valido),
        .quadro_fim  (quadro_fim),
        .dist_free   (dist_free),
        .dist_att    (dist_att),
        .vel_max     (vel_max),
        .cfg_valid   ()
    );

    speed_control #(.CLK_HZ (CLK_HZ)
    ) u_speed (
        .clk       (clk),
        .btn1      (btn1),
        .btn2      (btn2),
        .max_speed (vel_max),
        .speed     (speed)
    );

    // Esquerda: velocidade atual | Direita: vel_max recebida do Pi
    number_control u_display (
        .clk        (clk),
        .rst_n      (~rst),
        .value_a    ({6'd0, speed}),
        .value_b    ({6'd0, vel_max}),
        .number_din (number_din),
        .number_clk (number_clk),
        .number_cs  (number_cs)
    );

endmodule
