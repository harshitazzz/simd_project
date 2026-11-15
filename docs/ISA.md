# Instruction set (14-bit)

```
 13   10 9    7 6    4 3    1  0
+-------+------+------+------+----+
| opcode|  vd  | vs1  | vs2  | sb |
+-------+------+------+------+----+
```
`sb = 1` -> operand B of every lane is the scalar input (broadcast) instead of register `vs2`.
`opcode` is used directly as the ALU operation, so the control unit needs no decode table.

| Opcode | Mnemonic | Per-lane result | Example |
|---|---|---|---|
| 0 | VADD | a + b | `v3 = v1 + v2` |
| 1 | VSUB | a - b | |
| 2 | VAND | a & b | |
| 3 | VOR | a \| b | |
| 4 | VXOR | a ^ b | |
| 5 | VCMPEQ | (a == b) ? 0xFFFFFFFF : 0 | mask |
| 6 | VCMPLT | signed (a < b) ? 0xFFFFFFFF : 0 | `-1 < 1` is true |
| 7 | VSLL | a << b[4:0] | |
| 8 | VSRL | a >> b[4:0] (logical) | |
| 9 | VMUL | low 32 bits of a*b | uses DSP blocks |
| 10 | VMOV | b | with sb=1: broadcast scalar into vd |
| 11-15 | - | NOP, register file not written | |

Register file: 8 vector registers v0-v7, each `LANES x 32` bits. Lane *i* is bits `[i*32 +: 32]` (lane 0 = least significant).
Execution is one cycle: read -> ALU -> write at the next clock edge, so the next instruction sees the new value (no hazards in this design).
