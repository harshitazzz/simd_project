// vector_unit.sv
module vector_unit #(
    parameter int LANES = 4,
    parameter int WIDTH = 32
) (
    input  logic                     clk,
    input  logic                     rst_n,
    input  logic [1:0]               opcode,   // 00=ADD,01=SUB,10=AND,11=OR
    input  logic [LANES*WIDTH-1:0]   a_vec,
    input  logic [LANES*WIDTH-1:0]   b_vec,
    output logic [LANES*WIDTH-1:0]   y_vec
);

    // Generate lane‑wise ALU instances
    genvar i;
    generate
        for (i = 0; i < LANES; i=i+1) begin : lane
            // Slice packed vectors
            logic [WIDTH-1:0] a_lane = a_vec[i*WIDTH +: WIDTH];
            logic [WIDTH-1:0] b_lane = b_vec[i*WIDTH +: WIDTH];
            logic [WIDTH-1:0] y_lane;

            alu #(.WIDTH(WIDTH)) u_alu (
                .clk   (clk),
                .rst_n (rst_n),
                .opcode(opcode),
                .a     (a_lane),
                .b     (b_lane),
                .y     (y_lane)
            );

            assign y_vec[i*WIDTH +: WIDTH] = y_lane;
        end
    endgenerate

endmodule
