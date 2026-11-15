// -----------------------------------------------------------------------------
// fmax_wrap.v : timing wrapper, used ONLY for the Fmax / resource flow.
// simd_core has hundreds of I/O bits, more than any FPGA has pins. This wrapper
// feeds every input from one serial shift register and compresses every output
// into one flop, so the tool sees 4 pins and the REAL core logic is kept
// (nothing is optimised away). The critical path is register file -> ALU -> register file.
// -----------------------------------------------------------------------------
module fmax_wrap #(parameter LANES = 4, parameter W = 32)(
    input  clk, rst_n, din,
    output reg dout
);
    localparam IN_W = 1 + 14 + W + 1 + 3 + LANES*W + 3;
    reg [IN_W-1:0] sh;
    always @(posedge clk) sh <= {sh[IN_W-2:0], din};

    wire              instr_valid = sh[0];
    wire [13:0]       instr       = sh[14:1];
    wire [W-1:0]      scalar_in   = sh[14+W:15];
    wire              ld_en       = sh[15+W];
    wire [2:0]        ld_reg      = sh[18+W:16+W];
    wire [LANES*W-1:0] ld_data    = sh[18+W+LANES*W:19+W];
    wire [2:0]        st_reg      = sh[21+W+LANES*W:19+W+LANES*W];
    wire [LANES*W-1:0] st_data;

    simd_core #(.LANES(LANES), .W(W)) u_core (
        .clk(clk), .rst_n(rst_n), .instr_valid(instr_valid), .instr(instr),
        .scalar_in(scalar_in), .ld_en(ld_en), .ld_reg(ld_reg), .ld_data(ld_data),
        .st_reg(st_reg), .st_data(st_data));

    reg [LANES*W-1:0] st_q;
    always @(posedge clk) begin st_q <= st_data; dout <= ^st_q; end
endmodule
