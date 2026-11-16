#!/usr/bin/env python3
"""Combine cycle counts (results/compare.txt) with Fmax/resources (results/fmax.csv)
   -> results/summary.md : cycles, speed-up, execution time, throughput, area."""
import os, re
root = os.path.join(os.path.dirname(__file__), "..")
R = lambda f: os.path.join(root, "results", f)
cmp_ = {}
for line in open(R("compare.txt")):
    m = re.search(r"lanes=(\d+) N=(\d+) scalar_cycles=(\d+) simd_cycles=(\d+)", line)
    if m: cmp_[int(m.group(1))] = (int(m.group(2)), int(m.group(3)), int(m.group(4)))
fm = {}
if os.path.exists(R("fmax.csv")):
    for line in list(open(R("fmax.csv")))[1:]:
        p = line.strip().split(",")
        if len(p) == 5 and p[4]: fm[int(p[0])] = (int(p[1]), int(p[2]), int(p[3]), float(p[4]))
N = cmp_[1][0]; sc_cyc = cmp_[1][1]
f1 = fm.get(1, (0, 0, 0, None))[3]          # scalar reference clock = 1-lane datapath
out = ["# Scalar vs SIMD summary (N = %d, C = A + B)\n" % N,
       "| Lanes | Scalar cycles | SIMD cycles | Cycle speed-up | Elements/cycle | Fmax (MHz) | SIMD time (us) | Throughput (M elem/s) | Time speed-up | LUT4 | FF | MULT18 |",
       "|---|---|---|---|---|---|---|---|---|---|---|---|"]
for L in sorted(cmp_):
    n, cs, cv = cmp_[L]
    sp = cs / cv; epc = n / cv
    if L in fm:
        lut, ff, mul, f = fm[L]
        t = cv / f; thr = n / t              # cycles / MHz = microseconds ; elems/us = M elem/s
        ts = (sc_cyc / f1) / t if f1 else float("nan")
        row = f"| {L} | {cs} | {cv} | {sp:.2f}x | {epc:.3f} | {f:.1f} | {t:.1f} | {thr:.1f} | {ts:.2f}x | {lut} | {ff} | {mul} |"
    else:
        row = f"| {L} | {cs} | {cv} | {sp:.2f}x | {epc:.3f} | - | - | - | - | - | - | - |"
    out.append(row)
out.append("\nScalar reference time uses the 1-lane Fmax. Fmax/area: Yosys + nextpnr-ecp5 (Lattice ECP5-85k model), not Vivado/Quartus.\n")
open(R("summary.md"), "w").write("\n".join(out)); print("\n".join(out))
