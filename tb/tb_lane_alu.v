// -----------------------------------------------------------------------------
// tb_lane_alu.v  [Member 2]  unit test of ONE lane ALU, exhaustive on a small width
//   Part A: W=8, every (a,b) pair for every op  -> 65,536 x 11 checks, no gaps
//   Part B: W=32 directed + random
// -----------------------------------------------------------------------------
`timescale 1ns/1ps
module tb_lane_alu;
    // ---- Part A: 8-bit instance, exhaustive ----
    reg  [7:0] a8, b8;  reg [3:0] op;  wire [7:0] y8;
    lane_alu #(.W(8)) u8 (.a(a8), .b(b8), .op(op), .y(y8));

    // ---- Part B: 32-bit instance ----
    reg  [31:0] a32, b32;  wire [31:0] y32;
    lane_alu #(.W(32)) u32 (.a(a32), .b(b32), .op(op), .y(y32));

    integer errors = 0, checks = 0;
    integer i, j, o;
    reg [7:0]  e8;
    reg [31:0] e32;
    reg signed [7:0]  sa8, sb8;
    reg signed [31:0] sa32, sb32;

    function [7:0] gold8(input [3:0] o, input [7:0] a, input [7:0] b);
        reg signed [7:0] sa, sb;
        begin
            sa = a; sb = b;
            case (o)
                0: gold8 = a + b;       1: gold8 = a - b;
                2: gold8 = a & b;       3: gold8 = a | b;      4: gold8 = a ^ b;
                5: gold8 = (a == b) ? 8'hFF : 8'h00;
                6: gold8 = (sa < sb) ? 8'hFF : 8'h00;
                7: gold8 = a << b[2:0];
                8: gold8 = a >> b[2:0];
                9: gold8 = a * b;
                10: gold8 = b;
                default: gold8 = 0;
            endcase
        end
    endfunction

    function [31:0] gold32(input [3:0] o, input [31:0] a, input [31:0] b);
        reg signed [31:0] sa, sb;
        begin
            sa = a; sb = b;
            case (o)
                0: gold32 = a + b;      1: gold32 = a - b;
                2: gold32 = a & b;      3: gold32 = a | b;     4: gold32 = a ^ b;
                5: gold32 = (a == b) ? 32'hFFFFFFFF : 0;
                6: gold32 = (sa < sb) ? 32'hFFFFFFFF : 0;
                7: gold32 = a << b[4:0];
                8: gold32 = a >> b[4:0];
                9: gold32 = a * b;
                10: gold32 = b;
                default: gold32 = 0;
            endcase
        end
    endfunction

    initial begin
        // Part A: exhaustive 8-bit
        for (o = 0; o < 11; o = o + 1) begin
            op = o;
            for (i = 0; i < 256; i = i + 1)
                for (j = 0; j < 256; j = j + 1) begin
                    a8 = i; b8 = j; #1;
                    checks = checks + 1;
                    if (y8 !== gold8(o, a8, b8)) begin
                        errors = errors + 1;
                        if (errors < 10) $display("FAIL W8 op=%0d a=%h b=%h y=%h exp=%h", o, a8, b8, y8, gold8(o,a8,b8));
                    end
                end
        end
        // illegal opcodes -> 0
        for (o = 11; o < 16; o = o + 1) begin
            op = o; a8 = 8'h5A; b8 = 8'hA5; #1; checks = checks + 1;
            if (y8 !== 8'h00) begin errors = errors + 1; $display("FAIL illegal op %0d", o); end
        end
        // Part B: 32-bit corner + random
        for (o = 0; o < 11; o = o + 1) begin
            op = o;
            for (i = 0; i < 3000; i = i + 1) begin
                case (i)
                    0: begin a32 = 0;          b32 = 0;          end
                    1: begin a32 = 32'hFFFFFFFF; b32 = 1;        end
                    2: begin a32 = 32'h7FFFFFFF; b32 = 1;        end  // signed overflow
                    3: begin a32 = 32'h80000000; b32 = 1;        end
                    4: begin a32 = 32'hFFFFFFFF; b32 = 32'h1;    end  // -1 < 1
                    default: begin a32 = $random; b32 = $random; end
                endcase
                #1; checks = checks + 1;
                if (y32 !== gold32(o, a32, b32)) begin
                    errors = errors + 1;
                    if (errors < 10) $display("FAIL W32 op=%0d a=%h b=%h y=%h", o, a32, b32, y32);
                end
            end
        end
        $display("tb_lane_alu: checks=%0d errors=%0d", checks, errors);
        if (errors == 0) $display("RESULT: PASS"); else $display("RESULT: FAIL");
        $finish;
    end
endmodule
