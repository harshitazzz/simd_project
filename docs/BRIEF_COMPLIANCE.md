# Brief compliance - every sentence of the assignment, and the evidence

| Brief says | Status | Evidence (file / command) |
|---|---|---|
| Design a small SIMD unit performing multiple identical arithmetic/logic operations in parallel | Done | `rtl/simd_core.v`; waveform `docs/waveforms/fig1_parallel_lanes.png` |
| Data-level parallelism, SIMD, vector registers, parallel ALUs, throughput and speed-up | Done | README s.2-6; report |
| Module: Vector Register File | Done | `rtl/vreg_file.v`, `tb/tb_vreg_file.v` |
| Module: Multiple ALUs | Done | `rtl/lane_alu.v` x LANES (generate loop) |
| Module: Vector Control Unit | Done | `rtl/vctrl.v`, `tb/tb_vctrl.v` |
| Module: Lane MUXes | Done | operand-B mux inside the generate loop of `simd_core.v` |
| Module: Result Combiner | Done | `result[i*W +: W]` concatenation in `simd_core.v` |
| Module: Optional Scalar Interface | Done | `scalar_in` + `sb` bit (broadcast); tested in `tb_simd_core.v` (scalar-broadcast tests) |
| Operations: vector ADD, SUB, AND, OR, comparison | Done | opcodes 0,1,2,3,5,6 |
| Optionally shifts or multiply | Done | VSLL, VSRL, VMUL (opcodes 7, 8, 9) + VXOR, VMOV |
| Implement four or eight lanes | Done | `LANES` parameter; 1, 2, 4, 8 simulated and verified |
| Scalar and SIMD versions of the same workload | Done | `rtl/scalar_top.v` vs `rtl/bench_top.v`, `tb/tb_compare.v` (`make compare`) |
| Verify vector results | Done | `make test` (7 PASS lines), golden models, coverage matrix, 6 injected bugs caught |
| Measure cycle count | Done | `results/compare.txt`: 4097 vs 1025 vs 513 |
| Measure throughput | Done | elements/cycle and M elements/s in `results/summary.md` |
| Measure FPGA resource usage | Done (open-source flow) | `results/fmax.csv`, `results/pnr_L*.log` (LUT4, FF, MULT18) |
| Deliverable: SIMD RTL | Done | `rtl/` |
| Deliverable: vector testbench | Done | `tb/tb_simd_core.v` and unit testbenches |
| Deliverable: scalar-vs-SIMD timing comparison | Done | README s.5-6, report Tables II-III |
| Deliverable: resource utilization | Done (open-source flow) | README s.6 |
| Deliverable: maximum-frequency results | Done (open-source flow) | `results/fmax.csv`: 65.0 / 65.8 / 60.8 / 54.4 MHz |
| Evaluation: correct lane operation | Done | exhaustive ALU test, lane-independence test |
| Evaluation: parallel execution | Done | waveform figures 1 and 3 |
| Evaluation: verification coverage | Done | coverage matrix; `tb_*` test categories |
| Evaluation: quantitative performance analysis | Done | cycles, time, throughput, area, Fmax, Amdahl discussion |

## The one caveat to state openly
Maximum frequency and resource numbers come from **Yosys + nextpnr on a Lattice ECP5 model**, not from Vivado or Quartus. Say this in the
video and viva. The trend with lane count is the result; absolute MHz would differ on a Xilinx/Intel device. If a teammate has Vivado,
add its numbers to `results/` and one extra row in the README table.
