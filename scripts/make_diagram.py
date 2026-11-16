#!/usr/bin/env python3
"""Block diagram of the SIMD unit -> docs/diagrams/block_diagram.png  (matplotlib only)"""
import os
import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch

fig, ax = plt.subplots(figsize=(11, 6.6)); ax.set_xlim(0, 110); ax.set_ylim(0, 66); ax.axis("off")
def box(x, y, w, h, txt, fc="#e8f0fe", fs=9, bold=False):
    ax.add_patch(FancyBboxPatch((x, y), w, h, boxstyle="round,pad=0.3,rounding_size=1.2", fc=fc, ec="#1f4e9c", lw=1.4))
    ax.text(x + w/2, y + h/2, txt, ha="center", va="center", fontsize=fs, weight="bold" if bold else "normal")
def arrow(x1, y1, x2, y2, txt="", off=(0, 1.2)):
    ax.annotate("", xy=(x2, y2), xytext=(x1, y1), arrowprops=dict(arrowstyle="-|>", color="#333", lw=1.3))
    if txt: ax.text((x1+x2)/2 + off[0], (y1+y2)/2 + off[1], txt, fontsize=8, ha="center", color="#444")

box(2, 52, 24, 10, "Instruction\n{op, vd, vs1, vs2, sb}", "#fff4d6")
box(36, 52, 26, 10, "Vector Control Unit\n(vctrl.v)", "#fde2e2", bold=True)
box(2, 28, 28, 16, "Vector Register File\n(vreg_file.v)\n8 x (LANES x 32) bits\n2 read + 1 write port", "#dff3e3", bold=True)
box(76, 52, 28, 10, "Scalar input\n(broadcast to all lanes)", "#fff4d6")
box(40, 12, 64, 32, "", "#f6f6f6")
ax.text(72, 41, "SIMD execute stage (simd_core.v)", ha="center", fontsize=9, weight="bold")
for i in range(4):
    x = 43 + i * 15
    box(x, 29, 12, 6, f"Lane MUX {i}", "#fff4d6", fs=8)
    box(x, 17, 12, 8, f"lane_alu {i}\n(32-bit)", "#e8f0fe", fs=8, bold=True)
    arrow(x + 6, 29, x + 6, 25)
box(43, 5, 57, 6, "Result Combiner  (concatenate 4 x 32 -> 128 bits)", "#e1d9f7", fs=9)
for i in range(4): arrow(49 + i * 15, 17, 49 + i * 15, 11)
arrow(26, 57, 36, 57)
arrow(40, 52, 16, 44, "vs1, vs2, vd, write-enable", (-2, 3))
arrow(45, 52, 45, 44, "alu_op to ALL lanes", (10, 0))
arrow(90, 52, 90, 44, "scalar value", (8, 0))
arrow(30, 38, 43, 32, "A, B (128b each)", (-1, 3.5))
ax.plot([43, 12], [8, 8], color="#333", lw=1.3); ax.annotate("", xy=(12, 28), xytext=(12, 8), arrowprops=dict(arrowstyle="-|>", color="#333", lw=1.3))
ax.text(27, 9.2, "write-back to vd", fontsize=8, color="#444", ha="center")
ax.set_title("SIMD vector processing unit - block diagram (LANES = 4, W = 32)", fontsize=11)
out = os.path.join(os.path.dirname(__file__), "..", "docs", "diagrams"); os.makedirs(out, exist_ok=True)
fig.savefig(os.path.join(out, "block_diagram.png"), dpi=170, bbox_inches="tight"); print("wrote block_diagram.png")
