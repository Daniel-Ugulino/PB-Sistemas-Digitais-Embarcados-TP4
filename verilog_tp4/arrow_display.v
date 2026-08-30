module arrow_display (
    input  wire       clk,
    input  wire       rst_n,
    input  wire [1:0] direction,    // 00=frente, 01=esquerda, 10=direita, 11=tras
    output reg        arrow_din,
    output reg        arrow_clk,
    output reg        arrow_cs
);

    reg [7:0] arrow_up    [0:7];
    reg [7:0] arrow_left  [0:7];
    reg [7:0] arrow_right [0:7];
    reg [7:0] arrow_back  [0:7];

    initial begin
        arrow_up[0] = 8'b00011000;
        arrow_up[1] = 8'b00111100;
        arrow_up[2] = 8'b01111110;
        arrow_up[3] = 8'b00011000;
        arrow_up[4] = 8'b00011000;
        arrow_up[5] = 8'b00011000;
        arrow_up[6] = 8'b00011000;
        arrow_up[7] = 8'b00011000;

        arrow_left[0] = 8'b00001000;
        arrow_left[1] = 8'b00011000;
        arrow_left[2] = 8'b00111000;
        arrow_left[3] = 8'b01111111;
        arrow_left[4] = 8'b00111000;
        arrow_left[5] = 8'b00011000;
        arrow_left[6] = 8'b00001000;
        arrow_left[7] = 8'b00000000;

        arrow_right[0] = 8'b00010000;
        arrow_right[1] = 8'b00011000;
        arrow_right[2] = 8'b00011100;
        arrow_right[3] = 8'b11111110;
        arrow_right[4] = 8'b00011100;
        arrow_right[5] = 8'b00011000;
        arrow_right[6] = 8'b00010000;
        arrow_right[7] = 8'b00000000;

        arrow_back[0] = 8'b00011000;
        arrow_back[1] = 8'b00011000;
        arrow_back[2] = 8'b00011000;
        arrow_back[3] = 8'b00011000;
        arrow_back[4] = 8'b00011000;
        arrow_back[5] = 8'b01111110;
        arrow_back[6] = 8'b00111100;
        arrow_back[7] = 8'b00011000;
    end

    function [7:0] row_data;
        input [1:0] dir;
        input [2:0] row;
        begin
            case (dir)
                2'b00: row_data = arrow_up[row];
                2'b01: row_data = arrow_left[row];
                2'b10: row_data = arrow_right[row];
                2'b11: row_data = arrow_back[row];
                default: row_data = 8'b00000000;
            endcase
        end
    endfunction

    reg [15:0] init_table [0:3];
    initial begin
        init_table[0] = {8'h09, 8'h00};  // decode mode OFF (bits crus)
        init_table[1] = {8'h0B, 8'h07};  // scan limit 8 linhas
        init_table[2] = {8'h0A, 8'h08};  // intensidade media
        init_table[3] = {8'h0C, 8'h01};  // sai do shutdown
    end

    localparam INIT = 1'b0, RUN = 1'b1;
    localparam PH_SETUP = 2'd0, PH_RISE = 2'd1, PH_FALL = 2'd2;

    reg        phase;
    reg [1:0]  init_idx;
    reg [2:0]  row_index;   // 0..7
    reg [15:0] shift_reg;
    reg [4:0]  bit_cnt;
    reg [15:0] clk_div;
    reg        sending;
    reg [1:0]  clk_phase;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            phase       <= INIT;
            init_idx    <= 0;
            row_index   <= 0;
            arrow_cs  <= 1'b1;
            arrow_clk <= 1'b0;
            arrow_din <= 1'b0;
            clk_div     <= 0;
            sending     <= 1'b0;
            bit_cnt     <= 0;
            clk_phase   <= PH_SETUP;
        end else begin
            clk_div <= clk_div + 1;

            if (clk_div == 16'd50) begin
                clk_div <= 0;

                if (!sending) begin
                    if (phase == INIT)
                        shift_reg <= init_table[init_idx];
                    else
                        // 4 bits de padding + 4 bits de endereco + 8 bits de dado = 16
                        shift_reg <= {4'b0, (row_index + 4'd1), row_data(direction, row_index)};

                    bit_cnt     <= 5'd16;
                    arrow_cs  <= 1'b0;
                    sending     <= 1'b1;
                    clk_phase   <= PH_SETUP;
                    arrow_clk <= 1'b0;
                end else if (bit_cnt == 0) begin
                    arrow_cs  <= 1'b1;
                    arrow_clk <= 1'b0;
                    sending     <= 1'b0;

                    if (phase == INIT) begin
                        if (init_idx == 2'd3)
                            phase <= RUN;
                        else
                            init_idx <= init_idx + 2'd1;
                    end else begin
                        if (row_index == 3'd7)
                            row_index <= 0;
                        else
                            row_index <= row_index + 3'd1;
                    end
                end else begin
                    case (clk_phase)
                        PH_SETUP: begin
                            arrow_din <= shift_reg[15];
                            arrow_clk <= 1'b0;
                            clk_phase   <= PH_RISE;
                        end
                        PH_RISE: begin
                            arrow_clk <= 1'b1;
                            clk_phase   <= PH_FALL;
                        end
                        PH_FALL: begin
                            arrow_clk <= 1'b0;
                            shift_reg   <= shift_reg << 1;
                            bit_cnt     <= bit_cnt - 1;
                            clk_phase   <= PH_SETUP;
                        end
                    endcase
                end
            end
        end
    end

endmodule