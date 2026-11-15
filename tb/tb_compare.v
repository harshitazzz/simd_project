// -----------------------------------------------------------------------------
// tb_compare.v : the SAME workload on the SAME data, run on both machines
//   scalar_top (1 ALU)   vs   bench_top = SIMD (LANES ALUs)
//   Both are started together; each has its own cycle counter. Results of BOTH
//   are checked against a golden model for ADD, SUB, AND, OR, XOR.
//   Run:  iverilog -g2012 -Ptb_compare.LANES=4 -o x ../rtl/*.v tb_compare.v && vvp x
// -----------------------------------------------------------------------------
`timescale 1ns/1ps
module tb_compare;
    parameter LANES = 4;
    parameter N     = 1024;
    localparam W    = 32;
    localparam ITER = (N + LANES - 1) / LANES;

    reg clk = 0, rst_n = 0, start = 0;
    reg [3:0] op = 0;
    wire done_s, done_v;

    scalar_top #(.W(W), .N(N)) scal (.clk(clk), .rst_n(rst_n), .start(start), .op(op), .done(done_s));
    bench_top  #(.LANES(LANES), .W(W), .N(N)) simd (.clk(clk), .rst_n(rst_n), .start(start), .op(op), .done(done_v));

    always #5 clk = ~clk;

    reg [W-1:0] eA [0:N-1];
    reg [W-1:0] eB [0:N-1];
    reg [LANES*W-1:0] word;
    integer i, k, l, o, errors, cs, cv, cs_add, cv_add;
    reg run_s, run_v;

    function [W-1:0] golden(input [3:0] o, input [W-1:0] a, input [W-1:0] b);
        case (o) 0: golden = a + b; 1: golden = a - b; 2: golden = a & b;
                 3: golden = a | b; 4: golden = a ^ b; default: golden = 0; endcase
    endfunction

    initial begin
        for (i = 0; i < N; i = i + 1) begin
            eA[i] = $random; eB[i] = $random;
            scal.memA[i] = eA[i]; scal.memB[i] = eB[i];
        end
        for (k = 0; k < ITER; k = k + 1) begin
            word = 0; for (l = 0; l < LANES; l = l + 1) if (k*LANES+l < N) word[l*W +: W] = eA[k*LANES+l];
            simd.memA[k] = word;
            word = 0; for (l = 0; l < LANES; l = l + 1) if (k*LANES+l < N) word[l*W +: W] = eB[k*LANES+l];
            simd.memB[k] = word;
        end
        repeat (3) @(negedge clk); rst_n = 1; @(negedge clk);
        errors = 0;

        for (o = 0; o < 5; o = o + 1) begin
            op = o;
            @(negedge clk); start = 1; cs = 0; cv = 0;
            @(negedge clk); start = 0; cs = 1; cv = 1;
            // count every clock from the start handshake until done goes high (same rule as tb_bench)
            while (!(done_s && done_v)) begin
                run_s = !done_s; run_v = !done_v;
                @(negedge clk);
                if (run_s) cs = cs + 1;
                if (run_v) cv = cv + 1;
            end
            if (o == 0) begin cs_add = cs; cv_add = cv; end
            for (i = 0; i < N; i = i + 1) begin
                word = simd.memC[i / LANES];
                if (scal.memC[i] !== golden(o, eA[i], eB[i])) begin errors = errors + 1; if (errors < 5) $display("SCALAR mismatch op=%0d i=%0d", o, i); end
                if (word[(i % LANES)*W +: W] !== golden(o, eA[i], eB[i])) begin errors = errors + 1; if (errors < 5) $display("SIMD mismatch op=%0d i=%0d", o, i); end
            end
            @(negedge clk);
        end

        $display("COMPARE lanes=%0d N=%0d scalar_cycles=%0d simd_cycles=%0d speedup=%0f errors=%0d",
                 LANES, N, cs_add, cv_add, (1.0*cs_add)/cv_add, errors);
        if (errors == 0) $display("RESULT: PASS"); else $display("RESULT: FAIL");
        $finish;
    end
endmodule
