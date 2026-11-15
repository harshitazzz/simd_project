// -----------------------------------------------------------------------------
// tb_waves.v  [Member 5]  SHORT, readable demo used ONLY to create waveform
// pictures for the report/video. Small decimal values so the waveform is easy
// to read. Writes waves.vcd. Run with:  make waves
// -----------------------------------------------------------------------------
`timescale 1ns/1ps
module tb_waves;
    localparam LANES = 4, W = 32, VW = LANES*W;
    reg clk = 0, rst_n = 0, instr_valid = 0, ld_en = 0;
    reg [13:0] instr = 0;
    reg [W-1:0] scalar_in = 0;
    reg [2:0] ld_reg = 0, st_reg = 0;
    reg [VW-1:0] ld_data = 0;
    wire [VW-1:0] st_data;

    simd_core #(.LANES(LANES), .W(W)) dut (
        .clk(clk), .rst_n(rst_n), .instr_valid(instr_valid), .instr(instr),
        .scalar_in(scalar_in), .ld_en(ld_en), .ld_reg(ld_reg), .ld_data(ld_data),
        .st_reg(st_reg), .st_data(st_data));
    always #5 clk = ~clk;

    // ---- named probes so the plot script can find them easily ----
    wire [3:0] op   = dut.alu_op;
    wire [2:0] vd   = dut.vd;
    wire [2:0] vs1  = dut.vs1;
    wire [2:0] vs2  = dut.vs2;
    wire       sb   = dut.use_scalar;
    wire [W-1:0] a0 = dut.lane[0].op_a, a1 = dut.lane[1].op_a, a2 = dut.lane[2].op_a, a3 = dut.lane[3].op_a;
    wire [W-1:0] b0 = dut.lane[0].op_b, b1 = dut.lane[1].op_b, b2 = dut.lane[2].op_b, b3 = dut.lane[3].op_b;
    wire [W-1:0] y0 = dut.lane[0].y,    y1 = dut.lane[1].y,    y2 = dut.lane[2].y,    y3 = dut.lane[3].y;
    wire wr_en = dut.wr_en;

    task vload(input [2:0] r, input [W-1:0] l3, l2, l1, l0);
        begin ld_en = 1; ld_reg = r; ld_data = {l3, l2, l1, l0}; @(negedge clk); ld_en = 0; end
    endtask
    task vexec(input [3:0] o, input [2:0] d, s1, s2, input s);
        begin instr = {o, d, s1, s2, s}; instr_valid = 1; @(negedge clk); instr_valid = 0; end
    endtask

    initial begin
        $dumpfile("waves.vcd"); $dumpvars(0, tb_waves);
        repeat (2) @(negedge clk); rst_n = 1; @(negedge clk);
        vload(3'd1, 40, 30, 20, 10);               // v1 = {10,20,30,40}
        vload(3'd2,  4,  3,  2,  1);               // v2 = {1,2,3,4}
        vload(3'd0,  7,  3,  5, 32'hFFFFFFFF);     // v0 = {-1,5,3,7}
        vexec(4'd0, 3'd3, 3'd1, 3'd2, 0);          // VADD  v3 = v1 + v2
        vexec(4'd1, 3'd4, 3'd1, 3'd2, 0);          // VSUB  v4 = v1 - v2
        vexec(4'd2, 3'd5, 3'd1, 3'd2, 0);          // VAND  v5 = v1 & v2
        vexec(4'd6, 3'd6, 3'd0, 3'd2, 0);          // VCMPLT v6 = (v0 < v2)  signed, per lane
        scalar_in = 100;
        vexec(4'd0, 3'd7, 3'd1, 3'd0, 1);          // VADD  v7 = v1 + scalar(100) broadcast
        vexec(4'd0, 3'd3, 3'd3, 3'd3, 0);          // VADD  v3 = v3 + v3
        vexec(4'd0, 3'd3, 3'd3, 3'd3, 0);          // VADD  v3 = v3 + v3   (RAW back-to-back)
        repeat (2) @(negedge clk);
        st_reg = 3'd6; #1; $display("v6 (CMPLT mask) = %h", st_data);
        $finish;
    end
endmodule
