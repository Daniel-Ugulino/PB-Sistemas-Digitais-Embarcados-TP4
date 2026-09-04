module number_control (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [13:0] value_a,
    input  wire [13:0] value_b,
    output reg         number_din,
    output reg         number_clk,
    output reg         number_cs
);

    // ~10 us por passo => SPI de ~50 kHz (MAX7219 aceita ate 10 MHz)
    localparam TICK_MAX = 16'd270;

    localparam ST_LOAD  = 3'd0;
    localparam ST_SETUP = 3'd1;
    localparam ST_PULSE = 3'd2;
    localparam ST_FALL  = 3'd3;
    localparam ST_LATCH = 3'd4;

    reg [15:0] tick;
    reg [3:0]  frame_idx;
    reg [15:0] shift_reg;
    reg [4:0]  bit_cnt;
    reg [2:0]  state;

    reg [15:0] frame;
    reg [3:0]  digit;

    // MAX7219: 8 digitos, reg 1 = mais a direita.
    // Direita (1-4) = value_a vel_atual | Esquerda (5-8) = value_b vel_rec
    wire [3:0] a0 = value_a % 10;
    wire [3:0] a1 = (value_a / 10) % 10;
    wire [3:0] a2 = (value_a / 100) % 10;
    wire [3:0] a3 = (value_a / 1000) % 10;
    wire [3:0] b0 = value_b % 10;
    wire [3:0] b1 = (value_b / 10) % 10;
    wire [3:0] b2 = (value_b / 100) % 10;
    wire [3:0] b3 = (value_b / 1000) % 10;

    always @(*) begin
        case (frame_idx)
            4'd4:    digit = a0;
            4'd5:    digit = a1;
            4'd6:    digit = a2;
            4'd7:    digit = a3;
            4'd8:    digit = b0;
            4'd9:    digit = b1;
            4'd10:   digit = b2;
            default: digit = b3;
        endcase

        case (frame_idx)
            4'd0:    frame = 16'h09FF;
            4'd1:    frame = 16'h0B07;
            4'd2:    frame = 16'h0A08;
            4'd3:    frame = 16'h0C01;
            default: frame = {4'h0, frame_idx - 4'd3, 4'h0, digit};
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tick       <= 16'd0;
            frame_idx  <= 4'd0;
            shift_reg  <= 16'd0;
            bit_cnt    <= 5'd0;
            state      <= ST_LOAD;
            number_cs  <= 1'b1;
            number_clk <= 1'b0;
            number_din <= 1'b0;
        end else if (tick != TICK_MAX) begin
            tick <= tick + 16'd1;
        end else begin
            tick <= 16'd0;

            case (state)
                ST_LOAD: begin
                    shift_reg  <= frame;
                    bit_cnt    <= 5'd16;
                    number_cs  <= 1'b0;
                    number_clk <= 1'b0;
                    state      <= ST_SETUP;
                end

                ST_SETUP: begin
                    number_din <= shift_reg[15];
                    number_clk <= 1'b0;
                    state      <= ST_PULSE;
                end

                ST_PULSE: begin
                    number_clk <= 1'b1;
                    shift_reg  <= shift_reg << 1;
                    bit_cnt    <= bit_cnt - 5'd1;
                    state      <= (bit_cnt == 5'd1) ? ST_FALL : ST_SETUP;
                end

                ST_FALL: begin
                    number_clk <= 1'b0;
                    state      <= ST_LATCH;
                end

                ST_LATCH: begin
                    number_cs <= 1'b1;
                    frame_idx <= (frame_idx == 4'd11) ? 4'd0 : frame_idx + 4'd1;
                    state     <= ST_LOAD;
                end

                default: state <= ST_LOAD;
            endcase
        end
    end

endmodule
