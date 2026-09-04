module number_control (
    input wire clk,
    input wire rst_n,
    input wire [13:0] value_a,
    input wire [13:0] value_b,
    output reg number_din,
    output reg number_clk,
    output reg number_cs
);

    localparam TICK_MAX = 16'd270;

    localparam ST_START_FRAME = 3'd0;  
    localparam ST_OUTPUT_BIT = 3'd1; 
    localparam ST_CLOCK_HIGH = 3'd2; 
    localparam ST_CLOCK_LOW = 3'd3;  
    localparam ST_COMMIT_FRAME = 3'd4;

    reg [15:0] tick = 0;
    reg [3:0] frame_idx = 0;
    reg [15:0] shift_reg = 0;
    reg [4:0] bit_cnt = 0;
    reg [2:0] state = ST_START_FRAME;

    initial begin
        number_cs  = 1'b1;
        number_clk = 1'b0;
        number_din = 1'b0;
    end

    reg [15:0] frame;

    always @(*) begin
        case (frame_idx)
            4'd0: frame = 16'h0F00;
            4'd1: frame = 16'h09FF;
            4'd2: frame = 16'h0B07;
            4'd3: frame = 16'h0A08;
            4'd4:  frame = 16'h0C01;
            4'd5:  frame = 16'h0100 + (value_a % 10);
            4'd6:  frame = 16'h0200 + ((value_a / 10) % 10);
            4'd7:  frame = 16'h0300 + ((value_a / 100) % 10);
            4'd8:  frame = 16'h0400;
            4'd9:  frame = 16'h0500 + (value_b % 10);
            4'd10: frame = 16'h0600 + ((value_b / 10) % 10);
            4'd11: frame = 16'h0700 + ((value_b / 100) % 10);
            default: frame = 16'h0800;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tick <= 0;
            frame_idx <= 0;
            shift_reg <= 0;
            bit_cnt <= 0;
            state <= ST_START_FRAME;
            number_cs <= 1'b1;
            number_clk <= 1'b0;
            number_din <= 1'b0;
        end else if (tick != TICK_MAX) begin
            tick <= tick + 1;
        end else begin
            tick <= 0;

            case (state)
                ST_START_FRAME: begin
                    shift_reg  <= frame;
                    bit_cnt    <= 5'd16;
                    number_cs  <= 1'b0;
                    number_clk <= 1'b0;
                    state      <= ST_OUTPUT_BIT;
                end

                ST_OUTPUT_BIT: begin
                    number_din <= shift_reg[15];
                    number_clk <= 1'b0;
                    state      <= ST_CLOCK_HIGH;
                end

                ST_CLOCK_HIGH: begin
                    number_clk <= 1'b1;
                    shift_reg  <= shift_reg << 1;
                    bit_cnt    <= bit_cnt - 1;
                    state      <= (bit_cnt == 5'd1) ? ST_CLOCK_LOW : ST_OUTPUT_BIT;
                end

                ST_CLOCK_LOW: begin
                    number_clk <= 1'b0;
                    state      <= ST_COMMIT_FRAME;
                end

                ST_COMMIT_FRAME: begin
                    number_cs <= 1'b1;
                    frame_idx <= (frame_idx == 4'd12) ? 4'd0 : frame_idx + 1;
                    state     <= ST_START_FRAME;
                end

                default: state <= ST_START_FRAME;
            endcase
        end
    end

endmodule
