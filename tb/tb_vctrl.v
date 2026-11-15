// -----------------------------------------------------------------------------
// tb_vctrl.v  [Member 4]  unit test of the control unit / decoder
//   Every opcode 0..15, random register fields, valid=0, sb bit.
// -----------------------------------------------------------------------------
`timescale 1ns/1ps
module tb_vctrl;
    reg valid; reg [13:0] instr;
    wire we, use_scalar; wire [2:0] vd, vs1, vs2; wire [3:0] alu_op;
    vctrl dut (.valid(valid), .instr(instr), .we(we), .vd(vd), .vs1(vs1),
               .vs2(vs2), .alu_op(alu_op), .use_scalar(use_scalar));

    integer errors = 0, checks = 0, o, n;
    reg [2:0] d, s1, s2; reg sb;

    task chk(input cond, input [127:0] msg);
        begin checks = checks + 1; if (!cond) begin errors = errors + 1; $display("FAIL %0s instr=%h valid=%b", msg, instr, valid); end end
    endtask

    initial begin
        for (o = 0; o < 16; o = o + 1)
            for (n = 0; n < 100; n = n + 1) begin
                d = $random; s1 = $random; s2 = $random; sb = $random;
                instr = {o[3:0], d, s1, s2, sb};
                valid = 1; #1;
                chk(alu_op === o[3:0], "alu_op");
                chk(vd === d && vs1 === s1 && vs2 === s2, "reg fields");
                chk(use_scalar === sb, "scalar bit");
                chk(we === (o <= 10), "we only for legal opcodes");
                valid = 0; #1;
                chk(we === 1'b0, "valid=0 -> no write");
            end
        $display("tb_vctrl: checks=%0d errors=%0d", checks, errors);
        if (errors == 0) $display("RESULT: PASS"); else $display("RESULT: FAIL");
        $finish;
    end
endmodule
