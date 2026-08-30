module speed_control #(
    parameter CLK_HZ = 27_000_000
) (
    input  wire clk,
    input  wire btn1,
    input  wire btn2,
    input  wire [7:0] max_speed,
    output wire [7:0] speed
);

    localparam [7:0] STEP = 8'd5;
    localparam SAMPLE_MAX = CLK_HZ / 100;

    reg [18:0] sample_cnt = 19'd0;
    reg [7:0] speed_reg  = 8'd0;
    reg btn1_s = 1'b0;
    reg btn2_s = 1'b0;

    wire btn1_raw = ~btn1;
    wire btn2_raw = ~btn2;
    wire sample = (sample_cnt == SAMPLE_MAX - 1);

    wire [7:0] limit = (max_speed == 8'd0) ? 8'd120 : max_speed;
    wire [8:0] speed_up = {1'b0, speed_reg} + {1'b0, STEP};

    always @(posedge clk) begin
        sample_cnt <= sample ? 19'd0 : sample_cnt + 19'd1;

        if (sample) begin
            btn1_s <= btn1_raw;
            btn2_s <= btn2_raw;

            if (btn1_raw && !btn1_s)
                speed_reg <= (speed_up > {1'b0, limit}) ? limit : speed_up[7:0];
            else if (btn2_raw && !btn2_s)
                speed_reg <= (speed_reg < STEP) ? 8'd0 : speed_reg - STEP;
            else if (speed_reg > limit)
                speed_reg <= limit;
        end
    end

    assign speed = speed_reg;

endmodule
