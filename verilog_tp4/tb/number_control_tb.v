`timescale 1ns / 1ps

module number_control_tb;

    localparam CLK_NS = 10;

    reg         clk;
    reg         rst_n;
    reg  [13:0] value_a;
    reg  [13:0] value_b;
    wire        number_din;
    wire        number_clk;
    wire        number_cs;

    integer erros;
    integer i;
    integer guard;

    reg [15:0] frames [0:12];

    number_control dut (
        .clk        (clk),
        .rst_n      (rst_n),
        .value_a    (value_a),
        .value_b    (value_b),
        .number_din (number_din),
        .number_clk (number_clk),
        .number_cs  (number_cs)
    );

    initial clk = 1'b0;
    always #(CLK_NS/2) clk = ~clk;

    task check;
        input cond;
        input [255:0] name;
        begin
            if (cond)
                $display("OK   %0s", name);
            else begin
                $display("ERROR %0s", name);
                erros = erros + 1;
            end
        end
    endtask

    task get_frame;
        output [15:0] frame;
        integer b;
        begin
            frame = 16'd0;
            guard = 0;

            while (number_cs && guard < 200000) begin
                @(posedge clk);
                guard = guard + 1;
            end
            if (guard >= 200000) begin
                $display("ERROR get_frame: CS nao desceu");
                erros = erros + 1;
            end

            for (b = 0; b < 16; b = b + 1) begin
                @(posedge number_clk);
                frame = {frame[14:0], number_din};
            end

            guard = 0;
            while (!number_cs && guard < 200000) begin
                @(posedge clk);
                guard = guard + 1;
            end
        end
    endtask

    task collect_cycle;
        begin
            for (i = 0; i < 13; i = i + 1)
                get_frame(frames[i]);
        end
    endtask

    task expect_frame;
        input integer idx;
        input [15:0]  exp;
        input [255:0] name;
        begin
            if (frames[idx] === exp)
                $display("OK   %0s: [%0d]=0x%04h", name, idx, frames[idx]);
            else begin
                $display("ERROR %0s: [%0d]=0x%04h (exp 0x%04h)",
                         name, idx, frames[idx], exp);
                erros = erros + 1;
            end
        end
    endtask

    initial begin
        $dumpfile("tb/number_control_tb.vcd");
        $dumpvars(0, number_control_tb);

        erros   = 0;
        rst_n   = 1'b0;
        value_a = 14'd15;
        value_b = 14'd120;

        repeat (10) @(posedge clk);
        check(number_cs === 1'b1 && number_clk === 1'b0, "1 reset: CS alto, CLK baixo");

        rst_n = 1'b1;

        collect_cycle();

        expect_frame(0, 16'h0F00, "2 init display-test off");
        expect_frame(5, 16'h0105, "3 A unidade 5 (value_a=15)");
        expect_frame(11, 16'h0701, "4 B centena 1 (value_b=120)");

        if (erros == 0)
            $display("number_control: 4 testes OK");
        else
            $display("number_control: %0d FALHAS", erros);

        $finish;
    end

endmodule
