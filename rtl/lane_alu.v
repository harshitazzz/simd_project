// -----------------------------------------------------------------------------
// lane_alu.v : one SIMD lane = one ordinary W-bit ALU
//   op  0 ADD     1 SUB     2 AND     3 OR      4 XOR
//       5 CMPEQ   6 CMPLT (signed)    -> all-ones mask if true, else 0
//       7 SLL     8 SRL     9 MUL (low W bits)   10 PASSB (move / broadcast)
// -----------------------------------------------------------------------------
module lane_alu #(
    parameter W          = 32,
    parameter ENABLE_MUL = 1
)(
    input      [W-1:0] a,
    input      [W-1:0] b,
    input      [3:0]   op,
    output reg [W-1:0] y
);
    localparam SH = (W > 1) ? $clog2(W) : 1;
    wire [SH-1:0] shamt = b[SH-1:0];

    always @(*) begin
        case (op)
            4'd0:  y = a + b;
            4'd1:  y = a - b;
            4'd2:  y = a & b;
            4'd3:  y = a | b;
            4'd4:  y = a ^ b;
            4'd5:  y = (a == b)                  ? {W{1'b1}} : {W{1'b0}};
            4'd6:  y = ($signed(a) < $signed(b)) ? {W{1'b1}} : {W{1'b0}};
            4'd7:  y = a << shamt;
            4'd8:  y = a >> shamt;
            4'd9:  y = (ENABLE_MUL != 0) ? (a * b) : {W{1'b0}};
            4'd10: y = b;
            default: y = {W{1'b0}};
        endcase
    end
endmodule
