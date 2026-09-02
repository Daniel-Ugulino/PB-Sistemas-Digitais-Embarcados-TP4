module read_hc_sr04 #(
    parameter CLK_HZ      = 27_000_000,
    parameter TRIG_US     = 20,
    parameter BLIND_US    = 300,
    parameter STABLE_US   = 10,
    parameter MIN_ECHO_US = 100,
    parameter TIMEOUT_MS  = 30
) (
    input  wire       clk,
    input  wire       rst,
    input  wire       start,
    input  wire       echo,
    output reg        trig,
    output reg        busy,
    output reg  [7:0] distancia_cm,
    output reg        valido,
    output reg        timeout
);

    localparam US_TICKS       = (CLK_HZ / 1_000_000) > 0 ? (CLK_HZ / 1_000_000) : 1;
    localparam TRIG_CYCLES    = US_TICKS * TRIG_US;
    localparam BLIND_RAW      = (CLK_HZ / 1_000) * BLIND_US;
    localparam BLIND_CYCLES   = (CLK_HZ >= 1_000_000)
                              ? (CLK_HZ / 1_000_000) * BLIND_US
                              : ((BLIND_RAW / 1_000) > 0 ? BLIND_RAW / 1_000 : 1);
    localparam STABLE_RAW     = (CLK_HZ / 1_000) * STABLE_US;
    localparam STABLE_CYCLES  = (CLK_HZ >= 1_000_000)
                              ? (CLK_HZ / 1_000_000) * STABLE_US
                              : ((STABLE_RAW / 1_000) > 0 ? STABLE_RAW / 1_000 : 1);
    localparam MIN_ECHO_RAW    = (CLK_HZ / 1_000) * MIN_ECHO_US;
    localparam MIN_ECHO_CYCLES = (CLK_HZ >= 1_000_000)
                               ? (CLK_HZ / 1_000_000) * MIN_ECHO_US
                               : ((MIN_ECHO_RAW / 1_000) > 0 ? MIN_ECHO_RAW / 1_000 : 1);
    localparam TIMEOUT_RAW    = (CLK_HZ / 1_000) * TIMEOUT_MS;
    localparam TIMEOUT_CYCLES = (TIMEOUT_RAW > 0) ? TIMEOUT_RAW : 1;

    localparam CM_SHIFT_N = 20;
    localparam [63:0] CM_DEN    = (CLK_HZ > 0 ? CLK_HZ : 1) * 64'd58;
    localparam [63:0] CM_NUM    = (64'd1 << CM_SHIFT_N) * 64'd1_000_000;
    localparam [63:0] CM_MULT_K = (CM_NUM + (CM_DEN >> 1)) / CM_DEN;

    wire [63:0] prod_w     = contador * CM_MULT_K;
    wire [23:0] dist_raw_w = prod_w[CM_SHIFT_N + 23 : CM_SHIFT_N];
    wire [7:0]  dist_cm_w  = (dist_raw_w > 24'd255) ? 8'd255 : dist_raw_w[7:0];

    localparam S_IDLE      = 3'd0;
    localparam S_TRIG      = 3'd1;
    localparam S_BLIND     = 3'd2;
    localparam S_WAIT_RISE = 3'd3;
    localparam S_MEASURE   = 3'd4;

    reg [2:0]  estado;
    reg [23:0] contador;
    reg [1:0]  echo_s;
    reg [15:0] echo_stable;

    wire echo_sync = echo_s[1];
    wire echo_rise_ok = echo_sync && (echo_stable >= STABLE_CYCLES);

    always @(posedge clk) begin
        if (rst)
            echo_s <= 2'b00;
        else
            echo_s <= {echo_s[0], echo};
    end

    always @(posedge clk) begin
        if (rst)
            echo_stable <= 16'd0;
        else if (echo_sync)
            echo_stable <= (echo_stable < STABLE_CYCLES) ? echo_stable + 16'd1 : echo_stable;
        else
            echo_stable <= 16'd0;
    end

    always @(posedge clk) begin
        if (rst) begin
            estado       <= S_IDLE;
            contador     <= 24'd0;
            trig         <= 1'b0;
            busy         <= 1'b0;
            distancia_cm <= 8'd0;
            valido       <= 1'b0;
            timeout      <= 1'b0;
        end else begin
            valido  <= 1'b0;
            timeout <= 1'b0;

            case (estado)
                S_IDLE: begin
                    trig <= 1'b0;
                    busy <= 1'b0;
                    if (start) begin
                        busy     <= 1'b1;
                        contador <= 24'd0;
                        trig     <= 1'b1;
                        estado   <= S_TRIG;
                    end
                end

                S_TRIG: begin
                    if (contador >= TRIG_CYCLES - 1) begin
                        trig     <= 1'b0;
                        contador <= 24'd0;
                        estado   <= S_BLIND;
                    end else
                        contador <= contador + 24'd1;
                end

                S_BLIND: begin
                    if (contador >= BLIND_CYCLES - 1) begin
                        contador <= 24'd0;
                        estado   <= S_WAIT_RISE;
                    end else
                        contador <= contador + 24'd1;
                end

                S_WAIT_RISE: begin
                    if (echo_rise_ok) begin
                        contador <= 24'd0;
                        estado   <= S_MEASURE;
                    end else if (contador >= TIMEOUT_CYCLES - 1) begin
                        timeout <= 1'b1;
                        busy    <= 1'b0;
                        estado  <= S_IDLE;
                    end else
                        contador <= contador + 24'd1;
                end

                S_MEASURE: begin
                    if (!echo_sync) begin
                        if (contador >= MIN_ECHO_CYCLES) begin
                            distancia_cm <= dist_cm_w;
                            valido       <= 1'b1;
                            busy         <= 1'b0;
                            estado       <= S_IDLE;
                        end else begin
                            contador <= 24'd0;
                            estado   <= S_WAIT_RISE;
                        end
                    end else if (contador >= TIMEOUT_CYCLES - 1) begin
                        timeout <= 1'b1;
                        busy    <= 1'b0;
                        estado  <= S_IDLE;
                    end else
                        contador <= contador + 24'd1;
                end

                default: estado <= S_IDLE;
            endcase
        end
    end

endmodule
