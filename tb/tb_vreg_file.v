// -----------------------------------------------------------------------------
// tb_vreg_file.v  [Member 3]  unit test of the vector register file
//   reset clears, write then read each register, no write when we=0,
//   writing one register does not disturb the others, simultaneous
//   read of 3 ports, write+read same register (value visible NEXT cycle).
// -----------------------------------------------------------------------------
`timescale 1ns/1ps
module tb_vreg_file;
    parameter LANES = 4;
    localparam W = 32, VW = LANES*W;

    reg clk = 0, rst_n = 0, we = 0;
    reg [2:0] waddr = 0, ra = 0, rb = 0, rc = 0;
    reg [VW-1:0] wdata = 0;
    wire [VW-1:0] da, db, dc;

    vreg_file #(.LANES(LANES), .W(W)) dut (
        .clk(clk), .rst_n(rst_n), .we(we), .waddr(waddr), .wdata(wdata),
        .raddr_a(ra), .raddr_b(rb), .raddr_c(rc),
        .rdata_a(da), .rdata_b(db), .rdata_c(dc));

    always #5 clk = ~clk;

    integer errors = 0, checks = 0, i, j;
    reg [VW-1:0] model [0:7];
    reg [VW-1:0] r;

    task check(input [VW-1:0] got, input [VW-1:0] exp, input [127:0] msg);
        begin
            checks = checks + 1;
            if (got !== exp) begin errors = errors + 1; $display("FAIL %0s got=%h exp=%h", msg, got, exp); end
        end
    endtask

    task write(input [2:0] a, input [VW-1:0] d);
        begin
            @(negedge clk); we = 1; waddr = a; wdata = d;
            @(negedge clk); we = 0;
            model[a] = d;
        end
    endtask

    function [VW-1:0] rnd(input integer dummy);
        integer l;
        begin for (l = 0; l < LANES; l = l + 1) rnd[l*W +: W] = $random; end
    endfunction

    initial begin
        for (i = 0; i < 8; i = i + 1) model[i] = 0;
        repeat (2) @(negedge clk); rst_n = 1;

        // 1. reset value
        for (i = 0; i < 8; i = i + 1) begin ra = i; #1; check(da, 0, "reset"); end

        // 2. write each register with a different value, read all back
        for (i = 0; i < 8; i = i + 1) write(i[2:0], rnd(0));
        for (i = 0; i < 8; i = i + 1) begin
            ra = i; rb = 7 - i; rc = (i + 3) % 8; #1;
            check(da, model[i], "readA");
            check(db, model[7-i], "readB");
            check(dc, model[(i+3)%8], "readC");
        end

        // 3. we = 0 must not write
        @(negedge clk); we = 0; waddr = 3; wdata = {VW{1'b1}};
        @(negedge clk); ra = 3; #1; check(da, model[3], "we=0 holds");

        // 4. isolation: random write, all OTHER regs unchanged
        for (j = 0; j < 200; j = j + 1) begin
            i = $urandom % 8;
            write(i[2:0], rnd(0));
            for (i = 0; i < 8; i = i + 1) begin ra = i; #1; check(da, model[i], "isolation"); end
        end

        // 5. same-cycle read of a register being written returns the OLD value
        r = model[2];
        @(negedge clk); we = 1; waddr = 2; wdata = ~r; ra = 2; #1;
        check(da, r, "read-during-write = old value");
        @(negedge clk); we = 0; #1;
        check(da, ~r, "new value visible next cycle");

        // 6. async reset in the middle
        rst_n = 0; #2; ra = 5; #1; check(da, 0, "async reset"); rst_n = 1;

        $display("tb_vreg_file: LANES=%0d checks=%0d errors=%0d", LANES, checks, errors);
        if (errors == 0) $display("RESULT: PASS"); else $display("RESULT: FAIL");
        $finish;
    end
endmodule
