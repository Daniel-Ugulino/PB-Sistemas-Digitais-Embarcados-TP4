module arrow_display (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       enable,       // 0 = matriz apagada
    input  wire [1:0] direction,    // 00=frente, 01=esquerda, 10=direita, 11=tras
    output reg        arrow_din,
    output reg        arrow_clk,
    output reg        arrow_cs
);

    localparam TICK_MAX = 16'd270;

    localparam ST_START_FRAME = 3'd0;
    localparam ST_OUTPUT_BIT  = 3'd1;
    localparam ST_CLOCK_HIGH  = 3'd2;
    localparam ST_CLOCK_LOW   = 3'd3;
    localparam ST_COMMIT_FRAME = 3'd4;

    reg [15:0] tick      = 0;
    reg [3:0]  frame_idx = 0;
    reg [15:0] shift_reg = 0;
    reg [4:0]  bit_cnt   = 0;
    reg [2:0]  state     = ST_START_FRAME;

    function [7:0] row_pattern;
        input       on;
        input [1:0] dir;
        input [2:0] row;
        begin
            if (!on) begin
                row_pattern = 8'b00000000;
            end else begin
                case (dir)
                    2'b00: case (row)
                        3'd0: row_pattern = 8'b00011000;
                        3'd1: row_pattern = 8'b00111100;
                        3'd2: row_pattern = 8'b01111110;
                        3'd3: row_pattern = 8'b00011000;
                        3'd4: row_pattern = 8'b00011000;
                        3'd5: row_pattern = 8'b00011000;
                        3'd6: row_pattern = 8'b00011000;
                        3'd7: row_pattern = 8'b00011000;
                        default: row_pattern = 8'b00000000;
                    endcase
                    2'b01: case (row)
                        3'd0: row_pattern = 8'b00001000;
                        3'd1: row_pattern = 8'b00011000;
                        3'd2: row_pattern = 8'b00111000;
                        3'd3: row_pattern = 8'b01111111;
                        3'd4: row_pattern = 8'b00111000;
                        3'd5: row_pattern = 8'b00011000;
                        3'd6: row_pattern = 8'b00001000;
                        3'd7: row_pattern = 8'b00000000;
                        default: row_pattern = 8'b00000000;
                    endcase
                    2'b10: case (row)
                        3'd0: row_pattern = 8'b00010000;
                        3'd1: row_pattern = 8'b00011000;
                        3'd2: row_pattern = 8'b00011100;
                        3'd3: row_pattern = 8'b11111110;
                        3'd4: row_pattern = 8'b00011100;
                        3'd5: row_pattern = 8'b00011000;
                        3'd6: row_pattern = 8'b00010000;
                        3'd7: row_pattern = 8'b00000000;
                        default: row_pattern = 8'b00000000;
                    endcase
                    2'b11: case (row)
                        3'd0: row_pattern = 8'b00011000;
                        3'd1: row_pattern = 8'b00011000;
                        3'd2: row_pattern = 8'b00011000;
                        3'd3: row_pattern = 8'b00011000;
                        3'd4: row_pattern = 8'b00011000;
                        3'd5: row_pattern = 8'b01111110;
                        3'd6: row_pattern = 8'b00111100;
                        3'd7: row_pattern = 8'b00011000;
                        default: row_pattern = 8'b00000000;
                    endcase
                    default: row_pattern = 8'b00000000;
                endcase
            end
        end
    endfunction

    reg [15:0] frame;

    always @(*) begin
        case (frame_idx)
            4'd0:  frame = 16'h0F00;
            4'd1:  frame = 16'h0900;
            4'd2:  frame = 16'h0B07;
            4'd3:  frame = 16'h0A0F;
            4'd4:  frame = 16'h0C01;
            4'd5:  frame = {8'h01, row_pattern(enable, direction, 3'd0)};
            4'd6:  frame = {8'h02, row_pattern(enable, direction, 3'd1)};
            4'd7:  frame = {8'h03, row_pattern(enable, direction, 3'd2)};
            4'd8:  frame = {8'h04, row_pattern(enable, direction, 3'd3)};
            4'd9:  frame = {8'h05, row_pattern(enable, direction, 3'd4)};
            4'd10: frame = {8'h06, row_pattern(enable, direction, 3'd5)};
            4'd11: frame = {8'h07, row_pattern(enable, direction, 3'd6)};
            default: frame = {8'h08, row_pattern(enable, direction, 3'd7)};
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tick       <= 0;
            frame_idx  <= 0;
            shift_reg  <= 0;
            bit_cnt    <= 0;
            state      <= ST_START_FRAME;
            arrow_cs   <= 1'b1;
            arrow_clk  <= 1'b0;
            arrow_din  <= 1'b0;
        end else if (tick != TICK_MAX) begin
            tick <= tick + 1;
        end else begin
            tick <= 0;

            case (state)
                ST_START_FRAME: begin
                    shift_reg  <= frame;
                    bit_cnt    <= 5'd16;
                    arrow_cs   <= 1'b0;
                    arrow_clk  <= 1'b0;
                    state      <= ST_OUTPUT_BIT;
                end

                ST_OUTPUT_BIT: begin
                    arrow_din <= shift_reg[15];
                    arrow_clk <= 1'b0;
                    state     <= ST_CLOCK_HIGH;
                end

                ST_CLOCK_HIGH: begin
                    arrow_clk <= 1'b1;
                    shift_reg <= shift_reg << 1;
                    bit_cnt   <= bit_cnt - 1;
                    state     <= (bit_cnt == 5'd1) ? ST_CLOCK_LOW : ST_OUTPUT_BIT;
                end

                ST_CLOCK_LOW: begin
                    arrow_clk <= 1'b0;
                    state     <= ST_COMMIT_FRAME;
                end

                ST_COMMIT_FRAME: begin
                    arrow_cs  <= 1'b1;
                    frame_idx <= (frame_idx == 4'd12) ? 4'd0 : frame_idx + 1;
                    state     <= ST_START_FRAME;
                end

                default: state <= ST_START_FRAME;
            endcase
        end
    end

endmodule
