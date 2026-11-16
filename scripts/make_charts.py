#!/usr/bin/env python3
"""Charts from results/compare.txt + results/fmax.csv -> docs/diagrams/results_chart.png"""
import os, re
import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt
root = os.path.join(os.path.dirname(__file__), "..")
cmp_ = {}
for line in open(os.path.join(root, "results", "compare.txt")):
    m = re.search(r"lanes=(\d+) N=(\d+) scalar_cycles=(\d+) simd_cycles=(\d+)", line)
    if m: cmp_[int(m.group(1))] = (int(m.group(3)), int(m.group(4)))
fm = {}
for line in list(open(os.path.join(root, "results", "fmax.csv")))[1:]:
    L, lut, ff, mul, f = line.strip().split(","); fm[int(L)] = (int(lut), float(f))
lanes = sorted(cmp_)
cyc_sp = [cmp_[L][0] / cmp_[L][1] for L in lanes]
time_sp = [(cmp_[1][0] / fm[1][1]) / (cmp_[L][1] / fm[L][1]) for L in lanes]
fig, ax = plt.subplots(1, 3, figsize=(12, 3.5))
ax[0].plot(lanes, lanes, "--", color="gray", label="ideal")
ax[0].plot(lanes, cyc_sp, "o-", label="cycle speed-up")
ax[0].plot(lanes, time_sp, "s-", label="time speed-up (cycles/Fmax)")
ax[0].set_xlabel("lanes"); ax[0].set_ylabel("speed-up vs scalar"); ax[0].set_xticks(lanes); ax[0].legend(fontsize=7)
ax[0].set_title("Speed-up")
ax[1].bar([str(L) for L in lanes], [fm[L][1] for L in lanes], color="#2a7f62")
for i, L in enumerate(lanes): ax[1].text(i, fm[L][1], f"{fm[L][1]:.1f}", ha="center", va="bottom", fontsize=8)
ax[1].set_xlabel("lanes"); ax[1].set_ylabel("Fmax (MHz)"); ax[1].set_title("Max frequency (ECP5, nextpnr)")
ax[2].bar([str(L) for L in lanes], [fm[L][0] for L in lanes], color="#1f4e9c")
for i, L in enumerate(lanes): ax[2].text(i, fm[L][0], str(fm[L][0]), ha="center", va="bottom", fontsize=8)
ax[2].set_xlabel("lanes"); ax[2].set_ylabel("LUT4"); ax[2].set_title("Area (placed design)")
fig.tight_layout(); fig.savefig(os.path.join(root, "docs", "diagrams", "results_chart.png"), dpi=170); print("wrote results_chart.png")
