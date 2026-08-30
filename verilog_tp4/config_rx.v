// Recebe o pacote de configuracao Pi -> FPGA:
//   STX | 0x10 | dist_free | dist_att | vel_max | ETX
//

module config_rx #(
    parameter [7:0] DIST_FREE_INIT = 8'd100,
    parameter [7:0] DIST_ATT_INIT  = 8'd50,
    parameter [7:0] VEL_MAX_INIT   = 8'd120
) (
    input  wire       clk,
    input  wire       rst,

    input  wire [7:0] rx_byte,
    input  wire       byte_valido,
    input  wire       quadro_fim,

    output reg  [7:0] dist_free = DIST_FREE_INIT,
    output reg  [7:0] dist_att  = DIST_ATT_INIT,
    output reg  [7:0] vel_max   = VEL_MAX_INIT,
    output reg        cfg_valid = 1'b0
);

    localparam [7:0] STX      = 8'h02;
    localparam [7:0] ETX      = 8'h03;
    localparam [7:0] TYPE_CFG = 8'h10;

    localparam [2:0] ST_IDLE      = 3'd0;
    localparam [2:0] ST_TYPE      = 3'd1;
    localparam [2:0] ST_DIST_FREE = 3'd2;
    localparam [2:0] ST_DIST_ATT  = 3'd3;
    localparam [2:0] ST_VEL_MAX   = 3'd4;
    localparam [2:0] ST_ETX       = 3'd5;

    reg [2:0] state = ST_IDLE;
    reg [7:0] dist_free_s = DIST_FREE_INIT;
    reg [7:0] dist_att_s  = DIST_ATT_INIT;
    reg [7:0] vel_max_s   = VEL_MAX_INIT;

    always @(posedge clk) begin
        if (rst) begin
            state       <= ST_IDLE;
            dist_free   <= DIST_FREE_INIT;
            dist_att    <= DIST_ATT_INIT;
            vel_max     <= VEL_MAX_INIT;
            dist_free_s <= DIST_FREE_INIT;
            dist_att_s  <= DIST_ATT_INIT;
            vel_max_s   <= VEL_MAX_INIT;
            cfg_valid   <= 1'b0;
        end else begin
            cfg_valid <= 1'b0;

            if (quadro_fim && state != ST_IDLE)
                state <= ST_IDLE;
            else if (byte_valido) begin
                case (state)
                    ST_IDLE:
                        state <= (rx_byte == STX) ? ST_TYPE : ST_IDLE;

                    ST_TYPE:
                        state <= (rx_byte == TYPE_CFG) ? ST_DIST_FREE : ST_IDLE;

                    ST_DIST_FREE: begin
                        dist_free_s <= rx_byte;
                        state       <= ST_DIST_ATT;
                    end

                    ST_DIST_ATT: begin
                        dist_att_s <= rx_byte;
                        state      <= ST_VEL_MAX;
                    end

                    ST_VEL_MAX: begin
                        vel_max_s <= rx_byte;
                        state     <= ST_ETX;
                    end

                    ST_ETX: begin
                        if (rx_byte == ETX) begin
                            dist_free <= dist_free_s;
                            dist_att  <= dist_att_s;
                            vel_max   <= vel_max_s;
                            cfg_valid <= 1'b1;
                        end
                        state <= ST_IDLE;
                    end

                    default: state <= ST_IDLE;
                endcase
            end
        end
    end

endmodule
