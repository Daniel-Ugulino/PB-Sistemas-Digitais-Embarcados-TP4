// Velocidade do obstaculo a frente (km/h), janela hist[16] em BSRAM:
//   v_rel = (dist_nova - dist_mais_antiga) * 36 / dt_ms
//   v_obs = |vel_atual + v_rel|
//
// vel_atual entra porque o eco so ve o vao. Publica a partir de HIST_MIN
// amostras; ate la devolve vel_atual (vao ainda desconhecido).
//
// Por que BSRAM (16 x 8 bits por canal):
//   Ha 3 canais (E, C, D). Forcar bloco tira o historico das LUTRAM e
//   deixa LUTs para FSM, SPI e displays. A leitura e sincrona, que e a
//   porta nativa do BSRAM da Tang Nano.

module measure_speed #(
    parameter CLK_HZ     = 27_000_000,
    parameter HIST_DEPTH = 16,
    parameter HIST_MIN   = 4,
    parameter PTR_BITS   = 4
) (
    input  wire       clk,
    input  wire       rst,
    input  wire       amostra_valida,
    input  wire [7:0] distancia_cm,
    input  wire [7:0] vel_atual,
    output reg  [7:0] dist_atual,
    output reg  [7:0] velocidade
);

    localparam MS_CYCLES = (CLK_HZ / 1000) > 0 ? (CLK_HZ / 1000) : 1;
    localparam [PTR_BITS-1:0] PTR_LAST = HIST_DEPTH - 1;

    (* syn_ramstyle = "block_ram" *) reg [7:0]  hist   [0:HIST_DEPTH-1];
    (* syn_ramstyle = "block_ram" *) reg [15:0] t_hist [0:HIST_DEPTH-1];

    reg [PTR_BITS-1:0] ptr;
    reg [PTR_BITS:0]   contagem;
    reg [7:0]          hist_q;
    reg [15:0]         t_q;
    reg [31:0]         ms_div;
    reg [15:0]         now_ms;

    wire [PTR_BITS-1:0] rd_addr =
        (contagem == HIST_DEPTH) ? ptr : {PTR_BITS{1'b0}};

    wire [15:0] dt_ms = now_ms - t_q;

    wire signed [8:0] delta_w =
        $signed({1'b0, distancia_cm}) - $signed({1'b0, hist_q});

    wire signed [19:0] vel_num  = delta_w * 20'sd36;
    wire signed [19:0] dt_s     = $signed({4'b0, dt_ms});
    wire signed [19:0] vel_half = dt_s >>> 1;
    wire signed [19:0] vel_rel  = (dt_ms == 16'd0) ? 20'sd0 :
        (vel_num >= 20'sd0) ? (vel_num + vel_half) / dt_s
                            : (vel_num - vel_half) / dt_s;

    wire signed [20:0] vel_sum =
        $signed({13'b0, vel_atual}) + vel_rel;

    wire [20:0] vel_abs = vel_sum[20] ? -vel_sum : vel_sum;
    wire [7:0]  vel_sat = (vel_abs > 21'd255) ? 8'd255 : vel_abs[7:0];

    always @(posedge clk) begin
        if (rst) begin
            ms_div <= 32'd0;
            now_ms <= 16'd0;
        end else if (ms_div >= MS_CYCLES - 1) begin
            ms_div <= 32'd0;
            now_ms <= now_ms + 16'd1;
        end else
            ms_div <= ms_div + 32'd1;
    end

    always @(posedge clk) begin
        hist_q <= hist[rd_addr];
        t_q    <= t_hist[rd_addr];
        if (amostra_valida) begin
            hist[ptr]   <= distancia_cm;
            t_hist[ptr] <= now_ms;
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            ptr         <= {PTR_BITS{1'b0}};
            contagem    <= {(PTR_BITS+1){1'b0}};
            dist_atual  <= 8'd0;
            velocidade  <= 8'd0;
        end else if (amostra_valida) begin
            dist_atual <= distancia_cm;

            if (contagem >= (HIST_MIN - 1) && dt_ms != 16'd0)
                velocidade <= vel_sat;
            else
                velocidade <= vel_atual;

            if (ptr == PTR_LAST)
                ptr <= {PTR_BITS{1'b0}};
            else
                ptr <= ptr + 1'b1;
            if (contagem < HIST_DEPTH)
                contagem <= contagem + 1'b1;
        end
    end

endmodule
