// -----------------------------------------------------------------------------
// bench_top.v : benchmark wrapper  C[i] = A[i] <op> B[i],  i = 0..N-1
//   Memories hold one vector (LANES elements) per word.
//   FSM per iteration (4 cycles):  LDA -> LDB -> EXEC -> ST
//   LANES=1 -> scalar baseline (N iterations); LANES=L -> ceil(N/L) iterations.
//   Same FSM, same memory style, same clock => fair comparison.
// -----------------------------------------------------------------------------
module bench_top #(
    parameter LANES      = 4,
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
    localparam ITER = (N + LANES - 1) / LANES;       // leftover elements are padded
    localparam IW   = $clog2(ITER) + 1;

    reg [LANES*W-1:0] memA [0:ITER-1];
    reg [LANES*W-1:0] memB [0:ITER-1];
    reg [LANES*W-1:0] memC [0:ITER-1];

    localparam S_IDLE = 3'd0, S_LDA = 3'd1, S_LDB = 3'd2,
               S_EXEC = 3'd3, S_ST  = 3'd4, S_DONE = 3'd5;

    reg [2:0]    state;
    reg [IW-1:0] idx;

    reg                 ld_en, instr_valid;
    reg  [2:0]          ld_reg;
    reg  [LANES*W-1:0]  ld_data;
    wire [LANES*W-1:0]  st_data;
    wire [13:0]         instr = {op, 3'd3, 3'd1, 3'd2, 1'b0};   // v3 = v1 op v2

    simd_core #(.LANES(LANES), .W(W), .ENABLE_MUL(ENABLE_MUL)) u_core (
        .clk(clk), .rst_n(rst_n),
        .instr_valid(instr_valid), .instr(instr), .scalar_in({W{1'b0}}),
        .ld_en(ld_en), .ld_reg(ld_reg), .ld_data(ld_data),
        .st_reg(3'd3), .st_data(st_data)
    );

    always @(*) begin
        ld_en = 1'b0; ld_reg = 3'd0; ld_data = {LANES*W{1'b0}}; instr_valid = 1'b0;
        case (state)
            S_LDA:  begin ld_en = 1'b1; ld_reg = 3'd1; ld_data = memA[idx]; end
            S_LDB:  begin ld_en = 1'b1; ld_reg = 3'd2; ld_data = memB[idx]; end
            S_EXEC: instr_valid = 1'b1;
            default: ;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            idx   <= {IW{1'b0}};
        end else begin
            case (state)
                S_IDLE, S_DONE: if (start) begin idx <= 0; state <= S_LDA; end
                S_LDA:  state <= S_LDB;
                S_LDB:  state <= S_EXEC;
                S_EXEC: state <= S_ST;
                S_ST: begin
                    memC[idx] <= st_data;
                    if (idx == ITER-1) state <= S_DONE;
                    else begin idx <= idx + 1'b1; state <= S_LDA; end
                end
                default: state <= S_IDLE;
            endcase
        end
    end

    assign done = (state == S_DONE);
endmodule
