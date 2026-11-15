// -----------------------------------------------------------------------------
// tb_simd_core.v : self-checking vector testbench
//   Categories: directed, corner, random, scalar-broadcast, lane-independence,
//               back-to-back RAW hazards, illegal opcode
//   Run:  iverilog -g2012 -o sim_core ../rtl/*.v tb_simd_core.v && vvp sim_core
//   Lane count: add  -Ptb_simd_core.LANES=8
// -----------------------------------------------------------------------------
`timescale 1ns/1ps
module tb_simd_core;
    parameter LANES = 4;
    localparam W = 32;
    localparam VW = LANES*W;

    reg clk = 0, rst_n = 0;
    reg instr_valid = 0;
    reg [13:0] instr = 0;
    reg [W-1:0] scalar_in = 0;
    reg ld_en = 0;
    reg [2:0] ld_reg = 0;
    reg [VW-1:0] ld_data = 0;
    reg [2:0] st_reg = 0;
    wire [VW-1:0] st_data;

    simd_core #(.LANES(LANES), .W(W)) dut (
        .clk(clk), .rst_n(rst_n), .instr_valid(instr_valid), .instr(instr),
        .scalar_in(scalar_in), .ld_en(ld_en), .ld_reg(ld_reg), .ld_data(ld_data),
        .st_reg(st_reg), .st_data(st_data));

    always #5 clk = ~clk;

    // opcodes
    localparam VADD=0, VSUB=1, VAND=2, VOR=3, VXOR=4, VCMPEQ=5, VCMPLT=6,
               VSLL=7, VSRL=8, VMUL=9, VMOV=10;
    localparam NOPS = 11;
    localparam C_DIR=0, C_CORNER=1, C_RAND=2, C_SCAL=3, C_LANE=4, C_RAW=5;
    localparam NCAT = 6;

    integer errors = 0, checks = 0;
    integer cov [0:NOPS-1][0:NCAT-1];

    // ---------------- golden reference (behavioural, written independently) ---
    function [W-1:0] g_lane(input [3:0] op, input [W-1:0] a, input [W-1:0] b);
        reg signed [W-1:0] sa, sb;
        begin
            sa = a; sb = b;
            case (op)
                VADD:   g_lane = a + b;
                VSUB:   g_lane = a - b;
                VAND:   g_lane = a & b;
                VOR:    g_lane = a | b;
                VXOR:   g_lane = a ^ b;
                VCMPEQ: g_lane = (a == b) ? 32'hFFFFFFFF : 32'h0;
                VCMPLT: g_lane = (sa < sb) ? 32'hFFFFFFFF : 32'h0;
                VSLL:   g_lane = a << b[4:0];
                VSRL:   g_lane = a >> b[4:0];
                VMUL:   g_lane = a * b;
                VMOV:   g_lane = b;
                default:g_lane = 32'h0;
            endcase
        end
    endfunction

    function [VW-1:0] g_vec(input [3:0] op, input [VW-1:0] a, input [VW-1:0] b);
        integer l;
        begin
            for (l = 0; l < LANES; l = l + 1)
                g_vec[l*W +: W] = g_lane(op, a[l*W +: W], b[l*W +: W]);
        end
    endfunction

    function [VW-1:0] bcast(input [W-1:0] s);
        integer l;
        begin for (l = 0; l < LANES; l = l + 1) bcast[l*W +: W] = s; end
    endfunction

    // ---------------- bus-level tasks (called at a negedge) --------------------
    task vload(input [2:0] r, input [VW-1:0] d);
        begin
            ld_en = 1; ld_reg = r; ld_data = d;
            @(negedge clk);
            ld_en = 0;
        end
    endtask

    task vexec(input [3:0] op, input [2:0] vd, input [2:0] vs1, input [2:0] vs2, input sb);
        begin
            instr = {op, vd, vs1, vs2, sb}; instr_valid = 1;
            @(negedge clk);
            instr_valid = 0;
        end
    endtask

    task vcheck(input [2:0] r, input [VW-1:0] exp, input [255:0] name);
        begin
            st_reg = r; #1;
            checks = checks + 1;
            if (st_data !== exp) begin
                errors = errors + 1;
                $display("FAIL [%0s] reg v%0d got %h expected %h (t=%0t instr=%h)", name, r, st_data, exp, $time, instr);
            end
            @(negedge clk);          // re-align to the clock (one idle cycle)
        end
    endtask

    // load a, b into v1,v2; run op into v3; compare with golden
    task run_vv(input [3:0] op, input [VW-1:0] a, input [VW-1:0] b, input integer cat, input [255:0] name);
        begin
            vload(3'd1, a);
            vload(3'd2, b);
            vexec(op, 3'd3, 3'd1, 3'd2, 1'b0);
            vcheck(3'd3, g_vec(op, a, b), name);
            cov[op][cat] = cov[op][cat] + 1;
        end
    endtask

    task run_vs(input [3:0] op, input [VW-1:0] a, input [W-1:0] s);
        begin
            vload(3'd1, a);
            scalar_in = s;
            vexec(op, 3'd4, 3'd1, 3'd0, 1'b1);
            vcheck(3'd4, g_vec(op, a, bcast(s)), "scalar-bcast");
            cov[op][C_SCAL] = cov[op][C_SCAL] + 1;
        end
    endtask

    // ---------------- helpers ---------------------------------------------------
    function [W-1:0] corner(input integer k);
        case (k % 8)
            0: corner = 32'h00000000;
            1: corner = 32'h00000001;
            2: corner = 32'hFFFFFFFF;
            3: corner = 32'h7FFFFFFF;
            4: corner = 32'h80000000;
            5: corner = 32'hAAAAAAAA;
            6: corner = 32'h55555555;
            default: corner = 32'h0000001F;
        endcase
    endfunction

    reg [VW-1:0] va, vb, base, mod_r, t1, t2;
    integer op, i, j, l, n, cat;

    initial begin
        for (op = 0; op < NOPS; op = op + 1)
            for (cat = 0; cat < NCAT; cat = cat + 1) cov[op][cat] = 0;

        repeat (3) @(negedge clk);
        rst_n = 1;
        @(negedge clk);

        // reset check: all registers cleared
        for (i = 0; i < 8; i = i + 1) vcheck(i[2:0], {VW{1'b0}}, "reset");

        // ---------- 1. directed: distinct value in every lane --------------------
        for (op = 0; op < NOPS; op = op + 1) begin
            for (l = 0; l < LANES; l = l + 1) begin
                va[l*W +: W] = 32'h1000_0000 + l*32'h0101_0101 + 7;
                vb[l*W +: W] = 32'd3 + l;
            end
            run_vv(op, va, vb, C_DIR, "directed");
        end

        // ---------- 2. corner cases ---------------------------------------------
        for (op = 0; op < NOPS; op = op + 1)
            for (i = 0; i < 8; i = i + 1)
                for (j = 0; j < 8; j = j + 1) begin
                    for (l = 0; l < LANES; l = l + 1) begin
                        va[l*W +: W] = corner(i + l);
                        vb[l*W +: W] = corner(j + 2*l);
                    end
                    run_vv(op, va, vb, C_CORNER, "corner");
                end

        // ---------- 3. random ---------------------------------------------------
        for (op = 0; op < NOPS; op = op + 1)
            for (n = 0; n < 2000; n = n + 1) begin
                for (l = 0; l < LANES; l = l + 1) begin
                    va[l*W +: W] = $random;
                    vb[l*W +: W] = $random;
                end
                run_vv(op, va, vb, C_RAND, "random");
            end

        // ---------- 4. scalar broadcast (A op scalar) ----------------------------
        for (op = 0; op < NOPS; op = op + 1)
            for (n = 0; n < 200; n = n + 1) begin
                for (l = 0; l < LANES; l = l + 1) va[l*W +: W] = $random;
                run_vs(op, va, $random);
            end

        // ---------- 5. lane independence -----------------------------------------
        // change ONE lane of the inputs; every other lane's result must not move
        for (op = 0; op < NOPS; op = op + 1)
            for (l = 0; l < LANES; l = l + 1)
                for (n = 0; n < 50; n = n + 1) begin
                    for (j = 0; j < LANES; j = j + 1) begin
                        va[j*W +: W] = $random; vb[j*W +: W] = $random;
                    end
                    run_vv(op, va, vb, C_LANE, "lane-base");
                    base = st_data;
                    va[l*W +: W] = $random;           // perturb lane l only
                    vb[l*W +: W] = $random;
                    run_vv(op, va, vb, C_LANE, "lane-pert");
                    mod_r = st_data;
                    for (j = 0; j < LANES; j = j + 1)
                        if (j != l) begin
                            checks = checks + 1;
                            if (mod_r[j*W +: W] !== base[j*W +: W]) begin
                                errors = errors + 1;
                                $display("FAIL [lane-indep] op %0d: lane %0d changed when lane %0d was perturbed",
                                         op, j, l);
                            end
                        end
                end

        // ---------- 6. back-to-back RAW hazards (no gaps between instructions) ---
        for (n = 0; n < 500; n = n + 1) begin
            for (l = 0; l < LANES; l = l + 1) begin
                va[l*W +: W] = $random; vb[l*W +: W] = $random;
            end
            vload(3'd1, va);
            vload(3'd2, vb);
            vexec(VADD, 3'd3, 3'd1, 3'd2, 1'b0);   // v3 = v1 + v2
            vexec(VADD, 3'd4, 3'd3, 3'd3, 1'b0);   // v4 = v3 + v3   (RAW on v3)
            vexec(VSUB, 3'd5, 3'd4, 3'd1, 1'b0);   // v5 = v4 - v1   (RAW on v4)
            vexec(VXOR, 3'd5, 3'd5, 3'd2, 1'b0);   // v5 = v5 ^ v2   (RAW + WAW)
            t1 = g_vec(VADD, va, vb);
            t2 = g_vec(VXOR, g_vec(VSUB, g_vec(VADD, t1, t1), va), vb);
            vcheck(3'd5, t2, "RAW-chain");
            cov[VADD][C_RAW] = cov[VADD][C_RAW] + 1;
            cov[VSUB][C_RAW] = cov[VSUB][C_RAW] + 1;
            cov[VXOR][C_RAW] = cov[VXOR][C_RAW] + 1;
        end

        // accumulate into the same register 16 times: v1 = v1 + v2
        vload(3'd1, {VW{1'b0}});
        for (l = 0; l < LANES; l = l + 1) vb[l*W +: W] = l + 1;
        vload(3'd2, vb);
        for (n = 0; n < 16; n = n + 1) vexec(VADD, 3'd1, 3'd1, 3'd2, 1'b0);
        for (l = 0; l < LANES; l = l + 1) va[l*W +: W] = 16 * (l + 1);
        vcheck(3'd1, va, "accumulate");

        // ---------- 7. illegal opcode must not write ------------------------------
        vload(3'd6, {VW{1'b1}});
        vexec(4'd13, 3'd6, 3'd1, 3'd2, 1'b0);
        vcheck(3'd6, {VW{1'b1}}, "illegal-op-nop");

        // ---------- summary --------------------------------------------------------
        $display("");
        $display("Coverage matrix (number of vectors tested)");
        $display("op      directed  corner  random  scalar  lane-ind   RAW");
        for (op = 0; op < NOPS; op = op + 1)
            $display("%-6s %8d %7d %7d %7d %8d %5d",
                (op==0)?"VADD":(op==1)?"VSUB":(op==2)?"VAND":(op==3)?"VOR":(op==4)?"VXOR":
                (op==5)?"VCMPEQ":(op==6)?"VCMPLT":(op==7)?"VSLL":(op==8)?"VSRL":(op==9)?"VMUL":"VMOV",
                cov[op][0], cov[op][1], cov[op][2], cov[op][3], cov[op][4], cov[op][5]);
        $display("");
        $display("LANES=%0d  checks=%0d  errors=%0d", LANES, checks, errors);
        if (errors == 0) $display("RESULT: PASS"); else $display("RESULT: FAIL");
        $finish;
    end

    initial begin
        $dumpfile("tb_simd_core.vcd");
        $dumpvars(0, tb_simd_core);
    end
endmodule
