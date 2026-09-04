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

    reg [15:0] frames [0:11];

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
                $display("FAIL %0s", name);
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
                $display("FAIL get_frame: CS nao desceu");
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
            for (i = 0; i < 12; i = i + 1)
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
                $display("FAIL %0s: [%0d]=0x%04h (exp 0x%04h)",
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
        check(number_cs === 1'b1, "1 reset: CS alto");
        check(number_clk === 1'b0, "1 reset: CLK baixo");

        rst_n = 1'b1;

        // 12 quadros: 4 init + 8 digitos (MAX7219 1-8)
        collect_cycle();

        expect_frame(0, 16'h09FF, "2 init decode");
        expect_frame(1, 16'h0B07, "2 init scan-limit");
        expect_frame(2, 16'h0A08, "2 init intensity");
        expect_frame(3, 16'h0C01, "2 init shutdown off");

        // Direita A=15 → regs 1-4; esquerda B=120 → regs 5-8
        expect_frame(4,  16'h0105, "2 A unidade 5");
        expect_frame(5,  16'h0201, "2 A dezena 1");
        expect_frame(6,  16'h0300, "2 A centena 0");
        expect_frame(7,  16'h0400, "2 A milhar 0");
        expect_frame(8,  16'h0500, "2 B unidade 0");
        expect_frame(9,  16'h0602, "2 B dezena 2");
        expect_frame(10, 16'h0701, "2 B centena 1");
        expect_frame(11, 16'h0800, "2 B milhar 0");

        value_a = 14'd7;
        value_b = 14'd0;
        collect_cycle();

        expect_frame(4,  16'h0107, "3 A unidade 7");
        expect_frame(5,  16'h0200, "3 A dezena 0");
        expect_frame(8,  16'h0500, "3 B unidade 0");
        expect_frame(0,  16'h09FF, "3 volta ao init");

        value_a = 14'd255;
        value_b = 14'd100;
        collect_cycle();
        expect_frame(4,  16'h0105, "4 A=255 unidade");
        expect_frame(5,  16'h0205, "4 A=255 dezena");
        expect_frame(6,  16'h0302, "4 A=255 centena");
        expect_frame(8,  16'h0500, "4 B=100 unidade");
        expect_frame(9,  16'h0600, "4 B=100 dezena");
        expect_frame(10, 16'h0701, "4 B=100 centena");

        if (erros == 0)
            $display("number_control: testes OK");
        else
            $display("number_control: %0d FALHAS", erros);

        $finish;
    end

endmodule
