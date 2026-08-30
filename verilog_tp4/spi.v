module spi_slave (
    input  wire       clk,
    input  wire       rst,

    input  wire       sck,
    input  wire       mosi,
    input  wire       cs_n,
    output wire       miso,

    output reg  [7:0] rx_byte,
    output reg        byte_valido,

    input  wire [7:0] tx_byte,

    output wire       quadro_ativo,
    output wire       cs_desce,
    output reg        quadro_fim
);

    reg [2:0] sck_s  = 3'b000;
    reg [2:0] cs_s   = 3'b111;
    reg [1:0] mosi_s = 2'b00;

    always @(posedge clk) begin
        sck_s  <= {sck_s[1:0], sck};
        cs_s   <= {cs_s[1:0], cs_n};
        mosi_s <= {mosi_s[0], mosi};
    end

    wire ativo     = ~cs_s[1];
    wire sck_sobe  = (sck_s[2:1] == 2'b01);
    wire sck_desce = (sck_s[2:1] == 2'b10);
    wire cs_sobe   = (cs_s[2:1] == 2'b01);

    assign quadro_ativo = ativo;
    assign cs_desce     = (cs_s[2:1] == 2'b10);

    reg [7:0] rx_shift;
    reg [7:0] tx_shift;
    reg [2:0] bit_cnt;
    reg       recarregar;

    assign miso = tx_shift[7];

    always @(posedge clk) begin
        if (rst) begin
            rx_byte     <= 8'd0;
            byte_valido <= 1'b0;
            quadro_fim  <= 1'b0;
            rx_shift    <= 8'd0;
            tx_shift    <= 8'd0;
            bit_cnt     <= 3'd0;
            recarregar  <= 1'b0;
        end else begin
            byte_valido <= 1'b0;
            quadro_fim  <= 1'b0;

            if (cs_sobe) begin
                quadro_fim <= 1'b1;
            end else if (!ativo) begin
                bit_cnt    <= 3'd0;
                rx_shift   <= 8'd0;
                tx_shift   <= tx_byte;
                recarregar <= 1'b0;
            end else begin
                if (sck_sobe) begin
                    rx_shift <= {rx_shift[6:0], mosi_s[1]};
                    bit_cnt  <= bit_cnt + 3'd1;

                    if (bit_cnt == 3'd7) begin
                        rx_byte     <= {rx_shift[6:0], mosi_s[1]};
                        byte_valido <= 1'b1;
                        recarregar  <= 1'b1;
                    end
                end else if (sck_desce) begin
                    if (recarregar) begin
                        tx_shift   <= tx_byte;
                        recarregar <= 1'b0;
                    end else
                        tx_shift <= {tx_shift[6:0], 1'b0};
                end
            end
        end
    end

endmodule
