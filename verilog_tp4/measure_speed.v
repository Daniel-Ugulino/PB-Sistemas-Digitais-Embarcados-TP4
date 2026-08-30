// Velocidade do obstaculo sobre a janela hist[16] em BSRAM:
//   velocidade_cm = distancia_nova - distancia_mais_antiga
//   positivo = afastando | negativo = aproximando
// Publica a partir de 4 amostras (provisorio: nova - hist[0]).
// Com 16, a janela circular corrige: nova - mais antiga.
//
// Por que BSRAM (16 x 8 bits por canal):
//   Ha 3 canais (E, C, D). Forcar bloco tira o historico das LUTRAM e
//   deixa LUTs para FSM, SPI e displays. A leitura e sincrona, que e a
//   porta nativa do BSRAM da Tang Nano — o mesmo molde serve se a janela
//   crescer depois, sem mudar o acesso.

module measure_speed #(
    parameter HIST_DEPTH = 16,
    parameter HIST_MIN   = 4,
    parameter PTR_BITS   = 4
) (
    input  wire       clk,
    input  wire       rst,
    input  wire       amostra_valida,
    input  wire [7:0] distancia_cm,
    output reg  [7:0] dist_atual,
    output reg  signed [7:0] velocidade_cm
);

    (* syn_ramstyle = "block_ram" *) reg [7:0] hist [0:HIST_DEPTH-1];

    localparam [PTR_BITS-1:0] PTR_LAST = HIST_DEPTH - 1;

    reg [PTR_BITS-1:0] ptr;
    reg [PTR_BITS:0]   contagem;
    reg [7:0]          hist_q;

    // janela cheia: ptr = mais antiga; enquanto enche: mais antiga = hist[0]
    wire [PTR_BITS-1:0] rd_addr =
        (contagem == HIST_DEPTH) ? ptr : {PTR_BITS{1'b0}};

    // hist_q ja tem a amostra antiga (leitura no ciclo anterior; ptr fica
    // parado entre ecos, entao o valor esta estavel quando chega amostra_valida)
    wire signed [8:0] delta_w =
        $signed({1'b0, distancia_cm}) - $signed({1'b0, hist_q});

    always @(posedge clk) begin
        hist_q <= hist[rd_addr];
        if (amostra_valida)
            hist[ptr] <= distancia_cm;
    end

    always @(posedge clk) begin
        if (rst) begin
            ptr           <= {PTR_BITS{1'b0}};
            contagem      <= {(PTR_BITS+1){1'b0}};
            dist_atual    <= 8'd0;
            velocidade_cm <= 8'sd0;
        end else if (amostra_valida) begin
            dist_atual <= distancia_cm;

            if (contagem >= (HIST_MIN - 1)) begin
                if (delta_w > 9'sd127)
                    velocidade_cm <= 8'sd127;
                else if (delta_w < -9'sd128)
                    velocidade_cm <= -8'sd128;
                else
                    velocidade_cm <= delta_w[7:0];
            end else begin
                velocidade_cm <= 8'sd0;
            end

            if (ptr == PTR_LAST)
                ptr <= {PTR_BITS{1'b0}};
            else
                ptr <= ptr + 1'b1;
            if (contagem < HIST_DEPTH)
                contagem <= contagem + 1'b1;
        end
    end

endmodule
