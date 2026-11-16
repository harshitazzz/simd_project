#!/bin/bash
# Maximum frequency + FPGA resource usage with a fully open-source flow:
#   Yosys (synthesis) + nextpnr-ecp5 (place & route + static timing) on a Lattice ECP5-85k model.
# Install:  sudo apt-get install yosys nextpnr-ecp5
# NOTE: ECP5 is not Xilinx/Intel. Absolute MHz differ from Vivado/Quartus; the TREND vs lanes is what we report.
# Output: results/fmax.csv   (lanes,luts,ffs,mult18,fmax_mhz)
cd "$(dirname "$0")/.."
mkdir -p results build_fpga
[ -z "$APPEND" ] && echo "lanes,luts,ffs,mult18,fmax_mhz" > results/fmax.csv
for L in ${LANES_LIST:-1 2 4 8}; do
  echo "== LANES=$L =="
  yosys -q -p "read_verilog -sv rtl/lane_alu.v rtl/vreg_file.v rtl/vctrl.v rtl/simd_core.v synth/fmax_wrap.v;
               chparam -set LANES $L fmax_wrap;
               synth_ecp5 -top fmax_wrap -json build_fpga/l$L.json" >/dev/null 2>&1
  nextpnr-ecp5 --um5g-85k --package CABGA381 --json build_fpga/l$L.json --freq ${TARGET_MHZ:-100} --seed 1 \
      > results/pnr_L$L.log 2>&1
  fmax=$(grep "Max frequency for clock" results/pnr_L$L.log | tail -1 | sed -E 's/.*: ([0-9.]+) MHz.*/\1/')
  luts=$(grep -E "TRELLIS_COMB:" results/pnr_L$L.log | tail -1 | sed -E 's/.*TRELLIS_COMB: +([0-9]+)\/.*/\1/')
  ffs=$(grep -E "TRELLIS_FF:" results/pnr_L$L.log | tail -1 | sed -E 's/.*TRELLIS_FF: +([0-9]+)\/.*/\1/')
  mul=$(grep -E "MULT18X18D:" results/pnr_L$L.log | tail -1 | sed -E 's/.*MULT18X18D: +([0-9]+)\/.*/\1/')
  echo "$L,${luts:-0},${ffs:-0},${mul:-0},$fmax" | tee -a results/fmax.csv
done
