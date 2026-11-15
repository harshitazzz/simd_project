// -----------------------------------------------------------------------------
// simd_core.v : SIMD vector processing unit
//   LANES = 1 gives the SCALAR baseline (identical design, one lane)
//   Execute is single-cycle: read regs -> LANES parallel ALUs -> write back
//
//   ld_*  : load port  (memory / testbench -> vector register)
//   st_*  : store port (vector register -> memory / testbench)
//   scalar_in : scalar operand broadcast to every lane when sb = 1
// -----------------------------------------------------------------------------
module simd_core #(
    parameter LANES       = 4,
    parameter W           = 32,
    parameter ENABLE_MUL  = 1
)(
    input                   clk,
    input                   rst_n,
    input                   instr_valid,
    input      [13:0]       instr,
    input      [W-1:0]      scalar_in,
    input                   ld_en,
    input      [2:0]        ld_reg,
    input      [LANES*W-1:0] ld_data,
    input      [2:0]        st_reg,
    output     [LANES*W-1:0] st_data
);
    wire        ctl_we, use_scalar;
    wire [2:0]  vd, vs1, vs2;
    wire [3:0]  alu_op;

    vctrl u_ctrl (
        .valid(instr_valid), .instr(instr), .we(ctl_we),
        .vd(vd), .vs1(vs1), .vs2(vs2), .alu_op(alu_op), .use_scalar(use_scalar)
    );

    wire [LANES*W-1:0] rdata_a, rdata_b;
    wire [LANES*W-1:0] result;                 // result combiner output

    // ---- lanes: operand MUX + ALU, replicated LANES times --------------------
    genvar i;
    generate
        for (i = 0; i < LANES; i = i + 1) begin : lane
            wire [W-1:0] op_a = rdata_a[i*W +: W];
            wire [W-1:0] op_b = use_scalar ? scalar_in : rdata_b[i*W +: W]; // lane MUX
            wire [W-1:0] y;
            lane_alu #(.W(W), .ENABLE_MUL(ENABLE_MUL)) u_alu (
                .a(op_a), .b(op_b), .op(alu_op), .y(y)
            );
            assign result[i*W +: W] = y;       // result combiner (concatenation)
        end
    endgenerate

    // ---- write port arbitration: load port has priority ----------------------
    wire               wr_en   = ld_en | ctl_we;
    wire [2:0]         wr_addr = ld_en ? ld_reg  : vd;
    wire [LANES*W-1:0] wr_data = ld_en ? ld_data : result;

    vreg_file #(.LANES(LANES), .W(W)) u_rf (
        .clk(clk), .rst_n(rst_n),
        .we(wr_en), .waddr(wr_addr), .wdata(wr_data),
        .raddr_a(vs1), .raddr_b(vs2), .raddr_c(st_reg),
        .rdata_a(rdata_a), .rdata_b(rdata_b), .rdata_c(st_data)
    );
endmodule
