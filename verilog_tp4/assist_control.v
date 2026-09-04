module assist_control #(
    parameter REDUC_ATENCAO = 8'd20,
    parameter REDUC_CRITICO = 8'd40,
    parameter [7:0] LIMIAR_FECHA = 8'd10
) (
    input  wire [7:0] dist_e,
    input  wire [7:0] dist_c,
    input  wire [7:0] dist_d,
    input  wire [7:0] vel_e,
    input  wire [7:0] vel_c,
    input  wire [7:0] vel_d,
    input  wire [7:0] vel_atual,
    input  wire [7:0] cfg_dist_free,
    input  wire [7:0] cfg_dist_att,
    input  wire [7:0] cfg_vel_max,
    output reg  [7:0] vel_rec,
    output reg  [1:0] dir_fuga
);

    wire zona_livre_e = (dist_e > cfg_dist_free);
    wire zona_livre_c = (dist_c > cfg_dist_free);
    wire zona_livre_d = (dist_d > cfg_dist_free);

    wire zona_atencao_e = !zona_livre_e && (dist_e >= cfg_dist_att);
    wire zona_atencao_c = !zona_livre_c && (dist_c >= cfg_dist_att);
    wire zona_atencao_d = !zona_livre_d && (dist_d >= cfg_dist_att);
    wire zona_critico_c = !zona_livre_c && !zona_atencao_c;

    // fecha = quanto o obstaculo esta mais lento que o carro (km/h)
    wire saida_segura_e = ({1'b0, vel_atual} < ({1'b0, vel_e} + LIMIAR_FECHA));
    wire saida_segura_c = ({1'b0, vel_atual} < ({1'b0, vel_c} + LIMIAR_FECHA));
    wire saida_segura_d = ({1'b0, vel_atual} < ({1'b0, vel_d} + LIMIAR_FECHA));

    wire [7:0] reducao =
        zona_critico_c ? REDUC_CRITICO :
        zona_atencao_c ? REDUC_ATENCAO :
        8'd0;

    wire [7:0] vel_base = (vel_atual < cfg_vel_max) ? vel_atual : cfg_vel_max;
    wire signed [8:0] vel_tmp = vel_base - reducao;
    wire [7:0] vel_clamped =
        (vel_tmp <= 9'sd0) ? 8'd0 : vel_tmp[7:0];

    always @(*) begin
        vel_rec = vel_clamped;

        if (zona_livre_c && saida_segura_c)
            dir_fuga = 2'b00;
        else if (zona_livre_e && saida_segura_e)
            dir_fuga = 2'b01;
        else if (zona_livre_d && saida_segura_d)
            dir_fuga = 2'b10;
        else if (zona_atencao_c && saida_segura_c)
            dir_fuga = 2'b00;
        else if (zona_atencao_e && saida_segura_e)
            dir_fuga = 2'b01;
        else if (zona_atencao_d && saida_segura_d)
            dir_fuga = 2'b10;
        else
            dir_fuga = 2'b11;
    end

endmodule
