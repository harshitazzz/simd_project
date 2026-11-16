#!/usr/bin/env python3
"""Creates all waveform PNGs for the report/video. Run via:  make waves  (or python3 scripts/make_waveforms.py)"""
import os, sys
sys.path.insert(0, os.path.dirname(__file__))
from vcd_to_png import plot

OPS = "enum:0=VADD,1=VSUB,2=VAND,3=VOR,4=VXOR,5=VCMPEQ,6=VCMPLT,7=VSLL,8=VSRL,9=VMUL,10=VMOV"
out = os.path.join(os.path.dirname(__file__), "..", "docs", "waveforms")
os.makedirs(out, exist_ok=True)
sim = os.path.join(os.path.dirname(__file__), "..", "sim")
V = os.path.join(sim, "waves.vcd")
T = "tb_waves."

# ---- Figure 1: one instruction -> four lanes in parallel ----
rows = [("clk", V, T+"clk", "bit"), ("instr_valid", V, T+"instr_valid", "bit"),
        ("opcode", V, T+"op", OPS), ("vd", V, T+"vd", "dec"), ("vs1", V, T+"vs1", "dec"),
        ("vs2", V, T+"vs2", "dec"), ("scalar_sel", V, T+"sb", "bit")]
for L in range(4):
    rows += [(f"lane{L} A", V, T+f"a{L}", "sdec"), (f"lane{L} B", V, T+f"b{L}", "sdec"),
             (f"lane{L} Y=A op B", V, T+f"y{L}", "sdec")]
plot(rows, 50, 150, os.path.join(out, "fig1_parallel_lanes.png"),
     "Fig. 1  One instruction, four lanes: every lane computes its own A op B in the same cycle")

# ---- Figure 2: compact control + results only (nice for slides) ----
rows2 = [("clk", V, T+"clk", "bit"), ("opcode", V, T+"op", OPS), ("vd", V, T+"vd", "dec"),
         ("write_en", V, T+"wr_en", "bit")] + \
        [(f"lane{L} result", V, T+f"y{L}", "sdec") for L in range(4)]
plot(rows2, 50, 150, os.path.join(out, "fig2_results_per_lane.png"),
     "Fig. 2  Per-lane results (VADD, VSUB, VAND, signed VCMPLT, scalar broadcast, back-to-back RAW)")

# ---- Figure 3: scalar (1 lane) vs SIMD (4 lanes), same benchmark, N = 16 ----
b1, b4 = os.path.join(sim, "bench_L1.vcd"), os.path.join(sim, "bench_L4.vcd")
if os.path.exists(b1) and os.path.exists(b4):
    B = "tb_bench.dut."
    rows3 = [("SCALAR iteration", b1, B+"idx", "dec"), ("SCALAR done", b1, B+"done", "bit"),
             ("SIMD-4 iteration", b4, B+"idx", "dec"), ("SIMD-4 done", b4, B+"done", "bit")]
    plot(rows3, 20, 700, os.path.join(out, "fig3_scalar_vs_simd_timeline.png"),
         "Fig. 3  Same 16-element add: 4-lane SIMD finishes (done=1) at ~215 ns, scalar at ~695 ns", period=40)
