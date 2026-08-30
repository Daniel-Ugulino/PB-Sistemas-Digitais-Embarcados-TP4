// Envia telemetria Tang -> Pi via MISO em todo quadro SPI:
//   STX | 0x20 | speed | dist_e | dist_c | dist_d | dir | ETX

module config_tx (
    input  wire       clk,
    input  wire       rst,
    input  wire [7:0] speed,
    input  wire [7:0] dist_e,
    input  wire [7:0] dist_c,
    input  wire [7:0] dist_d,
    input  wire [1:0] dir,

    input  wire       cs_desce,
    input  wire       quadro_ativo,
    input  wire [7:0] rx_byte,
    input  wire       byte_valido,
    input  wire       quadro_fim,

    output reg  [7:0] tx_byte
);

    localparam [7:0] STX        = 8'h02;
    localparam [7:0] ETX        = 8'h03;
    localparam [7:0] TYPE_SPEED = 8'h20;

    reg [2:0] tx_idx = 3'd0;

    wire [7:0] dir_b = {6'b0, dir};

    // CS acabou de descer: o 1o bit de STX ja precisa estar no MISO
    wire [2:0] tx_idx_eff = cs_desce ? 3'd0 : tx_idx;

    always @(posedge clk) begin
        if (rst || !quadro_ativo)
            tx_idx <= 3'd0;
        else if (byte_valido)
            tx_idx <= tx_idx + 3'd1;
    end

    always @(*) begin
        case (tx_idx_eff)
            3'd0:    tx_byte = STX;
            3'd1:    tx_byte = TYPE_SPEED;
            3'd2:    tx_byte = speed;
            3'd3:    tx_byte = dist_e;
            3'd4:    tx_byte = dist_c;
            3'd5:    tx_byte = dist_d;
            3'd6:    tx_byte = dir_b;
            3'd7:    tx_byte = ETX;
            default: tx_byte = 8'h00;
        endcase
    end

endmodule
