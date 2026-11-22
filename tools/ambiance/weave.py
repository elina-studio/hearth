"""Gold weave rule (a two-strand braid) that divides the Ambiance columns.
    python3 tools/ambiance/weave.py out.svg   -> 14 x 930, render with shot.js"""
import sys, math
W, H, P = 14, 930, 30   # width, height, braid period
paths = []
for strand, ph in ((0, 0.0), (1, math.pi)):
    # draw the strand as short segments; the half that passes "under" is darker and drawn first
    for under in (True, False):
        for k in range(0, H, 2):
            a = 2 * math.pi * k / P + ph
            x1 = W / 2 + math.sin(a) * (W / 2 - 3)
            a2 = 2 * math.pi * (k + 2) / P + ph
            x2 = W / 2 + math.sin(a2) * (W / 2 - 3)
            is_under = math.cos(a) < 0
            if is_under != under:
                continue
            col = "#8a6a28" if under else "#e0b34a"
            paths.append(f'<line x1="{x1:.2f}" y1="{k}" x2="{x2:.2f}" y2="{k+2}" stroke="{col}" stroke-width="3.2" stroke-linecap="round"/>')
# a fine centre thread and highlights
body = "".join(paths)
body += f'<line x1="{W/2}" y1="0" x2="{W/2}" y2="{H}" stroke="#f2d38a" stroke-width="0.8" opacity=".35"/>'
open(sys.argv[1], "w").write(f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">{body}</svg>')
