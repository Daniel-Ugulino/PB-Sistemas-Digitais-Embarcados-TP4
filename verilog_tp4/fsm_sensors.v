module fsm_sensors #(
    parameter CLK_HZ     = 27_000_000,
    parameter GAP_MS     = 60,
    parameter TRIG_US    = 10,
    parameter TIMEOUT_MS = 30
) (
    input  wire       clk,
    input  wire       rst,
    input  wire       iniciar,
    input  wire       echo_e,
    input  wire       echo_c,
    input  wire       echo_d,
    output wire       trig_e,
    output wire       trig_c,
    output wire       trig_d,
    output reg  [7:0] dist_e,
    output reg  [7:0] dist_c,
    output reg  [7:0] dist_d,
    output reg        valid_e,
    output reg        valid_c,
    output reg        valid_d,
    output reg        ciclo_pronto,
    output reg  [3:0] estado_fsm
);

    localparam GAP_RAW    = (CLK_HZ / 1_000) * GAP_MS;
    localparam GAP_CYCLES = (GAP_RAW > 0) ? GAP_RAW : 1;

    localparam F_IDLE   = 4'd0;
    localparam F_MED_E  = 4'd1;
    localparam F_GAP_EC = 4'd2;
    localparam F_MED_C  = 4'd3;
    localparam F_GAP_CD = 4'd4;
    localparam F_MED_D  = 4'd5;
    localparam F_DONE   = 4'd6;
    localparam F_GAP_DE = 4'd7;

    reg [1:0] sensor_atual;
    reg       start_leitura;
    reg [31:0] gap_cnt;

    wire       echo_sel;
    wire       trig_leitura;
    wire       busy;
    wire       valido;
    wire       timeout;
    wire [7:0] dist_lida;

    read_hc_sr04 #(
        .CLK_HZ(CLK_HZ),
        .TRIG_US(TRIG_US),
        .TIMEOUT_MS(TIMEOUT_MS)
    ) leitor (
        .clk          (clk),
        .rst          (rst),
        .start        (start_leitura),
        .echo         (echo_sel),
        .trig         (trig_leitura),
        .busy         (busy),
        .distancia_cm (dist_lida),
        .valido       (valido),
        .timeout      (timeout)
    );

    assign echo_sel = (sensor_atual == 2'd0) ? echo_e :
                      (sensor_atual == 2'd1) ? echo_c : echo_d;

    assign trig_e = (sensor_atual == 2'd0) ? trig_leitura : 1'b0;
    assign trig_c = (sensor_atual == 2'd1) ? trig_leitura : 1'b0;
    assign trig_d = (sensor_atual == 2'd2) ? trig_leitura : 1'b0;

    always @(posedge clk) begin
        if (rst) begin
            estado_fsm    <= F_IDLE;
            sensor_atual  <= 2'd0;
            start_leitura <= 1'b0;
            gap_cnt       <= 32'd0;
            dist_e        <= 8'd0;
            dist_c        <= 8'd0;
            dist_d        <= 8'd0;
            valid_e       <= 1'b0;
            valid_c       <= 1'b0;
            valid_d       <= 1'b0;
            ciclo_pronto  <= 1'b0;
        end else begin
            start_leitura <= 1'b0;
            ciclo_pronto  <= 1'b0;
            valid_e       <= 1'b0;
            valid_c       <= 1'b0;
            valid_d       <= 1'b0;

            case (estado_fsm)
                F_IDLE: begin
                    if (iniciar) begin
                        sensor_atual  <= 2'd0;
                        start_leitura <= 1'b1;
                        estado_fsm    <= F_MED_E;
                    end
                end

                F_MED_E, F_MED_C, F_MED_D: begin
                    if (valido || timeout) begin
                        if (valido) begin
                            if (sensor_atual == 2'd0) begin
                                dist_e  <= dist_lida;
                                valid_e <= 1'b1;
                            end else if (sensor_atual == 2'd1) begin
                                dist_c  <= dist_lida;
                                valid_c <= 1'b1;
                            end else begin
                                dist_d  <= dist_lida;
                                valid_d <= 1'b1;
                            end
                        end

                        if (sensor_atual == 2'd2) begin
                            ciclo_pronto <= 1'b1;
                            estado_fsm   <= F_DONE;
                        end else begin
                            gap_cnt    <= 32'd0;
                            estado_fsm <= (sensor_atual == 2'd0) ? F_GAP_EC : F_GAP_CD;
                        end
                    end
                end

                F_GAP_EC, F_GAP_CD: begin
                    if (gap_cnt >= GAP_CYCLES - 1) begin
                        sensor_atual  <= sensor_atual + 2'd1;
                        start_leitura <= 1'b1;
                        estado_fsm    <= (estado_fsm == F_GAP_EC) ? F_MED_C : F_MED_D;
                    end else
                        gap_cnt <= gap_cnt + 32'd1;
                end

                F_DONE: begin
                    gap_cnt    <= 32'd0;
                    estado_fsm <= F_GAP_DE;
                end

                F_GAP_DE: begin
                    if (gap_cnt >= GAP_CYCLES - 1) begin
                        if (iniciar) begin
                            sensor_atual  <= 2'd0;
                            start_leitura <= 1'b1;
                            estado_fsm    <= F_MED_E;
                        end else
                            estado_fsm <= F_IDLE;
                    end else
                        gap_cnt <= gap_cnt + 32'd1;
                end

                default: estado_fsm <= F_IDLE;
            endcase
        end
    end

endmodule
