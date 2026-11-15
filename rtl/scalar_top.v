// -----------------------------------------------------------------------------
// scalar_top.v : SCALAR baseline (a separate design, NOT the SIMD core with 1 lane)
//   One 32-bit datapath: 3 scalar registers, ONE ALU (the same lane_alu used by
//   the SIMD lanes), and a controller that runs the same workload
//        C[i] = A[i] <op> B[i],   i = 0 .. N-1
//   Cycle rules (identical to the SIMD benchmark so the comparison is fair):
//     * a load moves ONE element per cycle   (SIMD load moves LANES elements per cycle)
//     * 4 cycles per iteration: LDA, LDB, EXEC, ST
//     * 1 extra cycle for the start transition
//   => scalar cycles = 4*N + 1,   SIMD cycles = 4*ceil(N/LANES) + 1
// -----------------------------------------------------------------------------
module scalar_top #(
    parameter W          = 32,
    parameter N          = 1024,
    parameter ENABLE_MUL = 1
)(
    input        clk,
    input        rst_n,
    input        start,
    input  [3:0] op,
    output       done
);
    localparam IW = $clog2(N) + 1;

    reg [W-1:0] memA [0:N-1];
    reg [W-1:0] memB [0:N-1];
    reg [W-1:0] memC [0:N-1];

    reg [W-1:0] ra, rb, rc;                 // scalar registers
    wire [W-1:0] y;                         // ALU result
    lane_alu #(.W(W), .ENABLE_MUL(ENABLE_MUL)) u_alu (.a(ra), .b(rb), .op(op), .y(y));

    localparam S_IDLE = 3'd0, S_LDA = 3'd1, S_LDB = 3'd2,
               S_EXEC = 3'd3, S_ST  = 3'd4, S_DONE = 3'd5;
    reg [2:0]    state;
    reg [IW-1:0] idx;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE; idx <= 0; ra <= 0; rb <= 0; rc <= 0;
        end else begin
            case (state)
                S_IDLE, S_DONE: if (start) begin idx <= 0; state <= S_LDA; end
                S_LDA:  begin ra <= memA[idx]; state <= S_LDB;  end
                S_LDB:  begin rb <= memB[idx]; state <= S_EXEC; end
                S_EXEC: begin rc <= y;         state <= S_ST;   end
                S_ST: begin
                    memC[idx] <= rc;
                    if (idx == N-1) state <= S_DONE;
                    else begin idx <= idx + 1'b1; state <= S_LDA; end
                end
                default: state <= S_IDLE;
            endcase
        end
    end

    assign done = (state == S_DONE);
endmodule
