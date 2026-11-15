// -----------------------------------------------------------------------------
// vctrl.v : Vector Control Unit (instruction decoder)
//
//   instr[13:10] opcode (= ALU op)
//   instr[9:7]   vd   destination vector register
//   instr[6:4]   vs1  source A
//   instr[3:1]   vs2  source B
//   instr[0]     sb   1 = operand B is the scalar input, broadcast to all lanes
// -----------------------------------------------------------------------------
module vctrl (
    input         valid,
    input  [13:0] instr,
    output        we,
    output [2:0]  vd,
    output [2:0]  vs1,
    output [2:0]  vs2,
    output [3:0]  alu_op,
    output        use_scalar
);
    assign alu_op     = instr[13:10];
    assign vd         = instr[9:7];
    assign vs1        = instr[6:4];
    assign vs2        = instr[3:1];
    assign use_scalar = instr[0];
    // only legal opcodes (0..10) write back; anything else is a NOP
    assign we         = valid && (instr[13:10] <= 4'd10);
endmodule
