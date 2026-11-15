// -----------------------------------------------------------------------------
// vreg_file.v : 8 vector registers, each LANES*W bits wide
//   3 combinational read ports (A, B for the ALU, C for store/readback)
//   1 synchronous write port
// -----------------------------------------------------------------------------
module vreg_file #(
    parameter LANES = 4,
    parameter W     = 32
)(
    input                  clk,
    input                  rst_n,
    input                  we,
    input      [2:0]       waddr,
    input      [LANES*W-1:0] wdata,
    input      [2:0]       raddr_a,
    input      [2:0]       raddr_b,
    input      [2:0]       raddr_c,
    output     [LANES*W-1:0] rdata_a,
    output     [LANES*W-1:0] rdata_b,
    output     [LANES*W-1:0] rdata_c
);
    reg [LANES*W-1:0] regs [0:7];
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 8; i = i + 1) regs[i] <= {LANES*W{1'b0}};
        end else if (we) begin
            regs[waddr] <= wdata;
        end
    end

    assign rdata_a = regs[raddr_a];
    assign rdata_b = regs[raddr_b];
    assign rdata_c = regs[raddr_c];
endmodule
