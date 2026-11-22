"""Divider options for the Ambiance panels (24 x 930 SVGs).  python3 dividers.py svg_dir"""
import sys, os, math, random
W, H = 24, 930
G, GD, GL = "#e0b34a", "#8a6a28", "#f2d38a"
def svg(name, body, defs=""):
    open(os.path.join(sys.argv[1], name), "w").write(f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}"><defs>{defs}</defs>{body}</svg>')
os.makedirs(sys.argv[1], exist_ok=True)

# 1 woven ribbon: a flat strap of two warp threads crossed by weft blocks, over-under
b = []
x0, bw = 5, 14
for k, y in enumerate(range(0, H, 10)):
    over = k % 2 == 0
    b.append(f'<rect x="{x0}" y="{y}" width="{bw/2:.1f}" height="10" fill="{G if over else GD}"/>')
    b.append(f'<rect x="{x0+bw/2:.1f}" y="{y}" width="{bw/2:.1f}" height="10" fill="{GD if over else G}"/>')
    b.append(f'<line x1="{x0}" y1="{y+0.5}" x2="{x0+bw}" y2="{y+0.5}" stroke="#5a4418" stroke-width="1" opacity=".6"/>')
b.append(f'<rect x="{x0-1}" y="0" width="1.4" height="{H}" fill="{GL}" opacity=".7"/><rect x="{x0+bw-0.4}" y="0" width="1.4" height="{H}" fill="{GL}" opacity=".7"/>')
svg("ribbon.svg", "".join(b))

# 2 double hairline with small diamond knots
b = [f'<rect x="9" y="0" width="1.6" height="{H}" fill="{G}"/><rect x="13.4" y="0" width="1.6" height="{H}" fill="{G}"/>']
for y in range(70, H, 160):
    b.append(f'<path d="M12,{y-11} L19,{y} L12,{y+11} L5,{y}Z" fill="#0b0e09" stroke="{G}" stroke-width="1.8"/><circle cx="12" cy="{y}" r="2.2" fill="{G}"/>')
svg("knots.svg", "".join(b))

# 3 gold vine with small leaves (echoes the lantern's vine)
R = random.Random(4)
pts = [(12 + 3.2 * math.sin(y / 38.0), y) for y in range(0, H + 1, 6)]
d = "M" + " L".join(f"{x:.1f},{y}" for x, y in pts)
b = [f'<path d="{d}" fill="none" stroke="{G}" stroke-width="1.6"/>']
side = 1
for y in range(30, H, 46):
    x = 12 + 3.2 * math.sin(y / 38.0)
    s = R.uniform(0.85, 1.15)
    lx, ly = x + side * 8 * s, y - 6 * s
    b.append(f'<path d="M{x:.1f},{y} Q{x+side*9*s:.1f},{y-1:.1f} {lx:.1f},{ly-5*s:.1f} Q{x+side*2*s:.1f},{y-7*s:.1f} {x:.1f},{y}Z" fill="{G}"/>')
    side = -side
svg("vine.svg", "".join(b))

# 4 single fine rule with a soft glow
svg("glow.svg", f'<rect x="7" y="0" width="10" height="{H}" fill="{G}" opacity=".10" filter="url(#b)"/><rect x="11" y="0" width="2" height="{H}" fill="{G}"/>',
    '<filter id="b" x="-100%" y="0" width="300%" height="100%"><feGaussianBlur stdDeviation="3"/></filter>')
