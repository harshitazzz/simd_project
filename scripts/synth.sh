#!/bin/bash
# Resource estimate with Yosys (free, open source).  Optional: apt install yosys
# Targets a Xilinx 7-series style LUT6 fabric (like Artix-7 / Basys 3).
cd "$(dirname "$0")/.."
mkdir -p results
: > results/resources.txt
for L in 1 2 4 8; do
  yosys -q -p "read_verilog -sv rtl/lane_alu.v rtl/vreg_file.v rtl/vctrl.v rtl/simd_core.v;
               chparam -set LANES $L simd_core;
               synth_xilinx -top simd_core -flatten;
               tee -o results/synth_L$L.rpt stat" >/dev/null 2>&1
  echo "== LANES=$L ==" | tee -a results/resources.txt
  grep -E "LUT[0-9]|FDCE|FDRE|DSP48|CARRY4|RAM|Number of cells" results/synth_L$L.rpt | tee -a results/resources.txt
done
