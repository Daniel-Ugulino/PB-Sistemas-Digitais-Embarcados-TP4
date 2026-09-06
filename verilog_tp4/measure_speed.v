// Velocidade do obstaculo a frente (km/h), janela hist[16] em BSRAM:
//   vel_vao = (dist_nova - dist_mais_antiga) * 36 / dt_ms
//   vel_obstaculo = vel_atual + vel_vao

module measure_speed #(
    parameter CLK_HZ       = 27_000_000,
    parameter TAM_JANELA   = 16,
    parameter AMOSTRAS_MIN = 4,
    parameter BITS_ENDERECO = 4
) (
    input  wire       clk,
    input  wire       rst,
    input  wire       amostra_valida,
    input  wire [7:0] distancia_cm,
    input  wire [7:0] vel_atual,
    output reg  [7:0] dist_atual,
    output reg  [7:0] vel_obstaculo
);

    localparam CICLOS_POR_MS = (CLK_HZ / 1000) > 0 ? (CLK_HZ / 1000) : 1;
    localparam [BITS_ENDERECO-1:0] ADDR_ULTIMO = TAM_JANELA - 1;

    (* syn_ramstyle = "block_ram" *) reg [7:0]  hist_dist  [0:TAM_JANELA-1];
    (* syn_ramstyle = "block_ram" *) reg [15:0] hist_tempo [0:TAM_JANELA-1];

    reg [BITS_ENDERECO-1:0] ptr_escrita;
    reg [BITS_ENDERECO:0]   n_amostras;
    reg [7:0]               dist_mais_antiga;
    reg [15:0]              tempo_mais_antiga;
    reg [31:0]              cnt_ciclos_ms;
    reg [15:0]              tempo_agora_ms;

    wire [BITS_ENDERECO-1:0] addr_mais_antiga =
        (n_amostras == TAM_JANELA) ? ptr_escrita : {BITS_ENDERECO{1'b0}};

    wire [15:0] dt_ms = tempo_agora_ms - tempo_mais_antiga;

    wire signed [8:0] delta_cm =
        $signed({1'b0, distancia_cm}) - $signed({1'b0, dist_mais_antiga});

    wire signed [19:0] vel_vao_num   = delta_cm * 20'sd36;
    wire signed [19:0] dt_ms_signed  = $signed({4'b0, dt_ms});
    wire signed [19:0] dt_ms_metade  = dt_ms_signed >>> 1;
    wire signed [19:0] vel_vao       = (dt_ms == 16'd0) ? 20'sd0 :
        (vel_vao_num >= 20'sd0) ? (vel_vao_num + dt_ms_metade) / dt_ms_signed
                                : (vel_vao_num - dt_ms_metade) / dt_ms_signed;

    wire signed [20:0] vel_obs_soma =
        $signed({13'b0, vel_atual}) + vel_vao;

    wire [20:0] vel_obs_abs = vel_obs_soma[20] ? -vel_obs_soma : vel_obs_soma;
    wire [7:0]  vel_obs_sat = (vel_obs_abs > 21'd255) ? 8'd255 : vel_obs_abs[7:0];

    always @(posedge clk) begin
        if (rst) begin
            cnt_ciclos_ms  <= 32'd0;
            tempo_agora_ms <= 16'd0;
        end else if (cnt_ciclos_ms >= CICLOS_POR_MS - 1) begin
            cnt_ciclos_ms  <= 32'd0;
            tempo_agora_ms <= tempo_agora_ms + 16'd1;
        end else
            cnt_ciclos_ms <= cnt_ciclos_ms + 32'd1;
    end

    always @(posedge clk) begin
        dist_mais_antiga  <= hist_dist[addr_mais_antiga];
        tempo_mais_antiga <= hist_tempo[addr_mais_antiga];
        if (amostra_valida) begin
            hist_dist[ptr_escrita]  <= distancia_cm;
            hist_tempo[ptr_escrita] <= tempo_agora_ms;
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            ptr_escrita   <= {BITS_ENDERECO{1'b0}};
            n_amostras    <= {(BITS_ENDERECO+1){1'b0}};
            dist_atual    <= 8'd0;
            vel_obstaculo <= 8'd0;
        end else if (amostra_valida) begin
            dist_atual <= distancia_cm;

            if (n_amostras >= (AMOSTRAS_MIN - 1) && dt_ms != 16'd0)
                vel_obstaculo <= vel_obs_sat;
            else
                vel_obstaculo <= vel_atual;

            if (ptr_escrita == ADDR_ULTIMO)
                ptr_escrita <= {BITS_ENDERECO{1'b0}};
            else
                ptr_escrita <= ptr_escrita + 1'b1;
            if (n_amostras < TAM_JANELA)
                n_amostras <= n_amostras + 1'b1;
        end
    end

endmodule
