#!/usr/bin/env python3
"""
vcd_to_png.py - draw digital waveforms from VCD files as PNG. NO GTKWave needed.
Only needs:  python3 + matplotlib   (pip install matplotlib)

Library use (see make_waveforms.py):
    plot(rows, t0_ns, t1_ns, "out.png", title="...")
    rows = [(label, vcd_file, "tb.signal.name", fmt), ...]
    fmt  = "bit" | "hex" | "dec" | "sdec" | "enum:0=ADD,1=SUB,..."
"""
import re
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

_cache = {}

def parse_vcd(path):
    if path in _cache:
        return _cache[path]
    names, changes, scope, factor = {}, {}, [], 1.0
    ts_unit = {"s": 1e9, "ms": 1e6, "us": 1e3, "ns": 1.0, "ps": 1e-3, "fs": 1e-6}
    t, in_defs, tok_ts = 0.0, True, False
    with open(path) as f:
        text = f.read().split()
    i = 0
    while i < len(text):
        w = text[i]
        if w == "$timescale":
            j = i + 1; buf = ""
            while text[j] != "$end":
                buf += text[j]; j += 1
            m = re.match(r"(\d+)(\w+)", buf)
            factor = int(m.group(1)) * ts_unit[m.group(2)]
            i = j
        elif w == "$scope":
            scope.append(text[i + 2]); i += 3
        elif w == "$upscope":
            scope.pop(); i += 1
        elif w == "$var":
            width, ident, name = int(text[i + 2]), text[i + 3], text[i + 4]
            full = ".".join(scope + [name])
            names[full] = (ident, width)
            changes.setdefault(ident, [])
            i += 5
        elif w == "$enddefinitions":
            in_defs = False
            i += 1
        elif in_defs:
            i += 1                      # skip $date/$version text etc.
        elif w.startswith("#"):
            t = int(w[1:]) * factor; i += 1
        elif w[0] in "01xXzZ" and len(w) > 1:
            changes[w[1:]].append((t, w[0].lower())); i += 1
        elif w[0] in "bB":
            changes[text[i + 1]].append((t, w[1:].lower())); i += 2
        else:
            i += 1
    _cache[path] = (names, changes)
    return _cache[path]


def _fmt_value(v, fmt, enum):
    if "x" in v or "z" in v:
        return "x"
    n = int(v, 2)
    if fmt == "hex":
        return format(n, "X")
    if fmt == "dec":
        return str(n)
    if fmt == "sdec":
        return str(n - (1 << len(v)) if v[0] == "1" and len(v) >= 32 else n)
    if fmt == "enum":
        return enum.get(n, str(n))
    return v


def _segments(chg, t0, t1):
    """value segments (start, end, value) clipped to [t0,t1]"""
    segs = []
    for k, (t, v) in enumerate(chg):
        end = chg[k + 1][0] if k + 1 < len(chg) else t1
        if end <= t0 or t >= t1:
            continue
        segs.append((max(t, t0), min(end, t1), v))
    return segs


def plot(rows, t0, t1, out, title="", period=10.0, width=14.0):
    n = len(rows)
    fig, ax = plt.subplots(figsize=(width, 0.55 * n + 1.3))
    h = 0.6
    for r, (label, vcd, sig, fmt) in enumerate(rows):
        names, changes = parse_vcd(vcd)
        if sig not in names:
            raise KeyError(f"{sig} not in {vcd}. Examples: {list(names)[:8]}")
        ident, wd = names[sig]
        enum = {}
        if fmt.startswith("enum:"):
            enum = {int(k): v for k, v in (p.split("=") for p in fmt[5:].split(","))}
            fmt = "enum"
        y0 = (n - 1 - r)
        segs = _segments(changes[ident], t0, t1)
        if fmt == "bit" or (wd == 1 and fmt not in ("enum",)):
            xs, ys = [], []
            for (a, b, v) in segs:
                lvl = 0.5 if v in "xz" else (1.0 if v == "1" else 0.0)
                xs += [a, b]; ys += [y0 + lvl * h, y0 + lvl * h]
            ax.step(xs, ys, where="post", color="#1f4e9c", lw=1.6)
        else:
            e = min(2.0, period * 0.12)
            for (a, b, v) in segs:
                txt = _fmt_value(v, fmt, enum)
                col = "#fde2e2" if txt == "x" else "#e8f0fe"
                xs = [a, a + e, b - e, b, b - e, a + e, a]
                ys = [y0 + h / 2, y0 + h, y0 + h, y0 + h / 2, y0, y0, y0 + h / 2]
                if b - a < 2 * e:
                    xs = [a, b, b, a, a]; ys = [y0, y0, y0 + h, y0 + h, y0]
                ax.fill(xs, ys, color=col, ec="#1f4e9c", lw=1.0)
                if (b - a) > 0.35 * period * max(1, len(txt) / 4.0):
                    ax.text((a + b) / 2, y0 + h / 2, txt, ha="center", va="center", fontsize=8)
    ax.set_yticks([(n - 1 - r) + 0.3 for r in range(n)])
    ax.set_yticklabels([row[0] for row in rows], fontsize=9, family="monospace")
    ax.set_xlim(t0, t1)
    ax.set_ylim(-0.3, n + 0.1)
    t = t0 - (t0 % period)
    while t <= t1:
        ax.axvline(t, color="#bbbbbb", lw=0.5, ls=":", zorder=0)
        t += period
    ax.set_xlabel("time (ns)")
    if title:
        ax.set_title(title, fontsize=11, loc="left")
    for s in ("top", "right"):
        ax.spines[s].set_visible(False)
    fig.tight_layout()
    fig.savefig(out, dpi=170)
    plt.close(fig)
    print("wrote", out)
