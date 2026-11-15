// -----------------------------------------------------------------------------
// tb_bench.v : scalar-vs-SIMD benchmark  C[i] = A[i] <op> B[i], N elements
//   Run:  iverilog -g2012 -Ptb_bench.LANES=4 -o sim_b ../rtl/*.v tb_bench.v && vvp sim_b
//   LANES=1 is the scalar baseline.
// -----------------------------------------------------------------------------
`timescale 1ns/1ps
module tb_bench;
    parameter LANES = 4;
    parameter N     = 1024;
    localparam W    = 32;
    localparam ITER = (N + LANES - 1) / LANES;

    reg clk = 0, rst_n = 0, start = 0;
    reg [3:0] op = 0;
    wire done;

    bench_top #(.LANES(LANES), .W(W), .N(N)) dut (
        .clk(clk), .rst_n(rst_n), .start(start), .op(op), .done(done));

    always #5 clk = ~clk;                 // 100 MHz nominal

    reg [W-1:0] eA [0:N-1];
    reg [W-1:0] eB [0:N-1];
    reg [LANES*W-1:0] word;

    function [W-1:0] golden(input [3:0] o, input [W-1:0] a, input [W-1:0] b);
        case (o)
            0: golden = a + b;
            1: golden = a - b;
            2: golden = a & b;
            3: golden = a | b;
            4: golden = a ^ b;
            default: golden = 0;
        endcase
    endfunction

    integer i, k, l, errors, cycles, o, nops;
    integer cycles_add;

    task run_once(input [3:0] o_in);
        begin
            op = o_in;
            @(negedge clk); start = 1;
            cycles = 0;
            @(negedge clk); start = 0;
            cycles = 1;
            while (!done) begin @(negedge clk); cycles = cycles + 1; end
        end
    endtask

    reg [255:0] vcdname;
    initial if ($value$plusargs("vcd=%s", vcdname)) begin $dumpfile(vcdname); $dumpvars(0, tb_bench); end

    initial begin
        for (i = 0; i < N; i = i + 1) begin eA[i] = $random; eB[i] = $random; end
        // pack elements into vector-wide memory words (pad leftovers with 0)
        for (k = 0; k < ITER; k = k + 1) begin
            word = 0;
            for (l = 0; l < LANES; l = l + 1)
                if (k*LANES + l < N) word[l*W +: W] = eA[k*LANES + l];
            dut.memA[k] = word;
            word = 0;
            for (l = 0; l < LANES; l = l + 1)
                if (k*LANES + l < N) word[l*W +: W] = eB[k*LANES + l];
            dut.memB[k] = word;
        end

        repeat (3) @(negedge clk); rst_n = 1; @(negedge clk);
        errors = 0;

        nops = $test$plusargs("once") ? 1 : 5;   // +once : only the ADD run (used for waveforms)
        for (o = 0; o < nops; o = o + 1) begin
            run_once(o[3:0]);
            if (o == 0) cycles_add = cycles;
            for (i = 0; i < N; i = i + 1) begin
                word = dut.memC[i / LANES];
                if (word[(i % LANES)*W +: W] !== golden(o[3:0], eA[i], eB[i])) begin
                    errors = errors + 1;
                    if (errors < 5) $display("MISMATCH op=%0d i=%0d", o, i);
                end
            end
            @(negedge clk);
        end

        $display("BENCH lanes=%0d N=%0d iterations=%0d cycles=%0d elements_per_cycle=%0f errors=%0d",
                 LANES, N, ITER, cycles_add, (1.0*N)/cycles_add, errors);
        if (errors == 0) $display("RESULT: PASS"); else $display("RESULT: FAIL");
        $finish;
    end
endmodule
