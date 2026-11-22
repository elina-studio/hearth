"""Painted backdrops for the Ambiance moods, as SVG. Rendered to PNG by shot.js.

    python3 tools/ambiance/art.py svg_dir
"""
import sys, os, math, random

R = random.Random(5)
W, H = 1920, 1080
FIREBOX = "rgb(17,11,7)"

TEX = """
<filter id="tex" x="0" y="0" width="100%" height="100%">
  <feTurbulence type="fractalNoise" baseFrequency="{f}" numOctaves="4" seed="{s}" result="n"/>
  <feColorMatrix in="n" type="matrix" values="0 0 0 0 0  0 0 0 0 0  0 0 0 0 0  0 0 0 {a} 0" result="a"/>
  <feComposite in="a" in2="SourceGraphic" operator="in" result="m"/>
  <feBlend in="SourceGraphic" in2="m" mode="multiply"/>
</filter>"""


def svg(body, defs="", w=W, h=H, bg=None):
    b = f'<rect width="{w}" height="{h}" fill="{bg}"/>' if bg else ""
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}"><defs>{defs}</defs>{b}{body}</svg>'


def blob(cx, cy, rx, ry, jitter=0.12, n=9, rot=0.0):
    pts = []
    for i in range(n):
        a = rot + 2 * math.pi * i / n
        r = 1 + R.uniform(-jitter, jitter)
        pts.append((cx + math.cos(a) * rx * r, cy + math.sin(a) * ry * r))
    # smooth closed curve through points (Catmull-Rom -> cubic Bezier)
    d = f"M{pts[0][0]:.1f},{pts[0][1]:.1f}"
    for i in range(n):
        p0, p1, p2, p3 = pts[i - 1], pts[i], pts[(i + 1) % n], pts[(i + 2) % n]
        c1 = (p1[0] + (p2[0] - p0[0]) / 6, p1[1] + (p2[1] - p0[1]) / 6)
        c2 = (p2[0] - (p3[0] - p1[0]) / 6, p2[1] - (p3[1] - p1[1]) / 6)
        d += f" C{c1[0]:.1f},{c1[1]:.1f} {c2[0]:.1f},{c2[1]:.1f} {p2[0]:.1f},{p2[1]:.1f}"
    return d + "Z"


def stone_fill(warm):
    # warm: 0..1 how much firelight reaches the stone
    v = R.randint(-7, 9)
    g = R.randint(-2, 4)
    base = (37 + v, 40 + v + g, 32 + v)
    lit = (120, 64, 30)
    c = [int(b + (l - b) * warm * R.uniform(0.7, 1.0)) for b, l in zip(base, lit)]
    return f"rgb({c[0]},{c[1]},{c[2]})"


# ---------------------------------------------------------------- hearth
ARCH_CX, ARCH_CY, ARCH_RX, ARCH_RY = 960, 440, 400, 150
OPEN_L, OPEN_R, FLOOR = 560, 1360, 962


def opening_path(grow=0):
    l, r = OPEN_L - grow, OPEN_R + grow
    rx, ry = ARCH_RX + grow, ARCH_RY + grow
    return f"M{l},{FLOOR} L{l},{ARCH_CY} A{rx},{ry} 0 0 1 {r},{ARCH_CY} L{r},{FLOOR}Z"


def hearth_bg():
    defs = TEX.format(f="0.9", s=3, a="0.55") + """
<radialGradient id="room" cx="50%" cy="62%" r="75%"><stop offset="0" stop-color="#1c1a10"/><stop offset=".55" stop-color="#0e120b"/><stop offset="1" stop-color="#070906"/></radialGradient>
<radialGradient id="warm" cx="960" cy="760" r="760" gradientUnits="userSpaceOnUse"><stop offset="0" stop-color="#ff8a30" stop-opacity=".40"/><stop offset=".45" stop-color="#c0501a" stop-opacity=".16"/><stop offset="1" stop-color="#000" stop-opacity="0"/></radialGradient>
<linearGradient id="beam" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#3a2717"/><stop offset=".5" stop-color="#2a1b10"/><stop offset="1" stop-color="#1a1009"/></linearGradient>
<linearGradient id="floor" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#5a3420"/><stop offset="1" stop-color="#191109"/></linearGradient>
<filter id="soft"><feGaussianBlur stdDeviation="2"/></filter>
<filter id="blur8"><feGaussianBlur stdDeviation="8"/></filter>
"""
    body = ['<rect width="1920" height="1080" fill="url(#room)"/>']
    # plaster wall texture
    body.append('<rect width="1920" height="1080" fill="#151a11" opacity=".55" filter="url(#tex)"/>')
    # stone surround: blobs packed around the opening
    stones = []
    for ring in range(3):
        grow = 18 + ring * 62
        k = 15 + ring * 3
        # arch stones
        for i in range(k + 1):
            a = math.pi + math.pi * i / k
            cx = ARCH_CX + math.cos(a) * (ARCH_RX + grow + 26)
            cy = ARCH_CY + math.sin(a) * (ARCH_RY + grow + 26)
            stones.append((cx, cy, 44 + R.uniform(-6, 10), 30 + R.uniform(-4, 6), a + math.pi / 2, ring))
        # side stones
        for side in (-1, 1):
            x = ARCH_CX + side * (ARCH_RX + grow + 26)
            y = ARCH_CY + 40
            while y < FLOOR + 10:
                h = R.uniform(46, 70)
                stones.append((x + R.uniform(-6, 6), y + h / 2, 40 + R.uniform(-4, 8), h / 2 + 1, 0, ring))
                y += h + 4
    body.append(f'<path d="{opening_path(215)}" fill="#0d0d09"/>')
    for cx, cy, rx, ry, rot, ring in stones:
        d = math.hypot((cx - 960) / 1.3, cy - 760)
        warm = max(0.0, 1 - d / 620) ** 1.6
        rr = rot
        body.append(f'<path d="{blob(cx, cy, rx, ry, 0.13, 9, rr)}" fill="{stone_fill(warm)}" stroke="#090a07" stroke-width="5"/>')
        # top highlight
        body.append(f'<path d="{blob(cx - rx * 0.1, cy - ry * 0.25, rx * 0.7, ry * 0.45, 0.15, 8, rr)}" fill="#fff" opacity="{0.03 + 0.05 * warm:.3f}" filter="url(#soft)"/>')
    # inner soot ring and the firebox
    body.append(f'<path d="{opening_path(10)}" fill="#0b0805"/>')
    body.append(f'<path d="{opening_path(0)}" fill="{FIREBOX}"/>')
    # mantel beam with moss
    body.append('<rect x="300" y="150" width="1320" height="70" rx="8" fill="url(#beam)"/>')
    body.append('<rect x="300" y="150" width="1320" height="70" rx="8" fill="#000" opacity=".5" filter="url(#tex)"/>')
    for i in range(70):
        x = 300 + R.uniform(0, 1320)
        body.append(f'<ellipse cx="{x:.0f}" cy="{150 + R.uniform(-4, 6):.0f}" rx="{R.uniform(8, 30):.0f}" ry="{R.uniform(4, 9):.0f}" fill="rgb({R.randint(50,75)},{R.randint(70,95)},{R.randint(28,40)})" opacity=".8" filter="url(#soft)"/>')
    for i in range(14):  # hanging moss strands
        x = 330 + R.uniform(0, 1260)
        l = R.uniform(20, 55)
        body.append(f'<path d="M{x:.0f},216 q{R.uniform(-6,6):.0f},{l/2:.0f} {R.uniform(-4,4):.0f},{l:.0f}" stroke="rgb(70,88,38)" stroke-width="{R.uniform(2,4):.1f}" fill="none" opacity=".7"/>')
    # a few things on the mantel: candle stubs and a jar, in silhouette
    body.append('<rect x="420" y="96" width="22" height="56" rx="3" fill="#cbb98a" opacity=".55"/><ellipse cx="431" cy="88" rx="5" ry="10" fill="#ffcf73" opacity=".9" filter="url(#soft)"/>')
    body.append('<rect x="1460" y="80" width="56" height="72" rx="14" fill="#2b3524" opacity=".9"/><rect x="1468" y="70" width="40" height="14" rx="4" fill="#3b2a1a"/>')
    body.append('<rect x="1380" y="112" width="18" height="40" rx="3" fill="#cbb98a" opacity=".5"/><ellipse cx="1389" cy="104" rx="4" ry="8" fill="#ffcf73" opacity=".85" filter="url(#soft)"/>')
    # hearth floor: a row of flat stones
    body.append(f'<rect x="0" y="{FLOOR}" width="1920" height="{H - FLOOR}" fill="#0b0c08"/>')
    x = 330
    while x < 1600:
        w = R.uniform(110, 170)
        d = abs(x + w / 2 - 960)
        warm = max(0, 1 - d / 700)
        body.append(f'<path d="M{x+4:.0f},{FLOOR+6} L{x+w-4:.0f},{FLOOR+6} L{x+w+18*(x+w/2-960)/600:.0f},{H-20} L{x-0+18*(x+w/2-960)/600:.0f},{H-20}Z" fill="{stone_fill(warm*0.9)}" stroke="#080806" stroke-width="5"/>')
        x += w
    # firelight over everything
    body.append('<rect width="1920" height="1080" fill="url(#warm)"/>')
    # make sure the firebox stays the exact flat colour the sprite fades to
    body.append(f'<path d="{opening_path(0)}" fill="{FIREBOX}"/>')
    # soot gradient at the top of the firebox (above the sprite area only)
    return svg("".join(body), defs)


def hearth_logs():
    # 760 x 170 overlay, placed at (580, 830) on screen
    w, h = 760, 170
    defs = """
<linearGradient id="bark" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#4a2c18"/><stop offset=".6" stop-color="#24150b"/><stop offset="1" stop-color="#120a05"/></linearGradient>
<radialGradient id="end" cx=".5" cy=".5" r=".5"><stop offset="0" stop-color="#c88a52"/><stop offset=".7" stop-color="#8a5a32"/><stop offset="1" stop-color="#3a2210"/></radialGradient>
<filter id="glow" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="3"/></filter>
<filter id="glow2" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="9"/></filter>"""
    b = []
    # ember bed
    b.append('<ellipse cx="380" cy="150" rx="330" ry="26" fill="#ff7a1c" opacity=".55" filter="url(#glow2)"/>')
    for i in range(90):
        x = 80 + R.uniform(0, 600); y = 140 + R.uniform(-6, 18)
        c = R.choice(["#ffb347", "#ff7a1c", "#e2501a", "#5a1a08", "#2a1006"])
        b.append(f'<ellipse cx="{x:.0f}" cy="{y:.0f}" rx="{R.uniform(6,16):.0f}" ry="{R.uniform(3,7):.0f}" fill="{c}"/>')
    # back log (horizontal), two crossed logs in front
    def log(x1, y1, x2, y2, r):
        ang = math.degrees(math.atan2(y2 - y1, x2 - x1))
        L = math.hypot(x2 - x1, y2 - y1)
        s = f'<g transform="translate({x1},{y1}) rotate({ang:.1f})">'
        s += f'<rect x="0" y="{-r}" width="{L:.0f}" height="{2*r}" rx="{r*0.6:.0f}" fill="url(#bark)"/>'
        for k in range(7):  # glowing cracks underneath
            cx = R.uniform(0.1, 0.9) * L
            s += f'<path d="M{cx:.0f},{r*0.55:.0f} l{R.uniform(10,30):.0f},{R.uniform(-3,3):.0f}" stroke="#ff9a3a" stroke-width="3" opacity=".9" filter="url(#glow)"/>'
        for k in range(5):  # bark lines
            yy = R.uniform(-r * 0.7, r * 0.3)
            s += f'<path d="M{R.uniform(0,L*0.3):.0f},{yy:.0f} l{R.uniform(L*0.3,L*0.6):.0f},{R.uniform(-4,4):.0f}" stroke="#120904" stroke-width="2" opacity=".6"/>'
        s += f'<ellipse cx="{L:.0f}" cy="0" rx="{r*0.45:.0f}" ry="{r:.0f}" fill="url(#end)"/>'
        s += f'<ellipse cx="{L:.0f}" cy="0" rx="{r*0.25:.0f}" ry="{r*0.55:.0f}" fill="none" stroke="#5a3418" stroke-width="2"/>'
        return s + "</g>"
    b.append(log(110, 110, 650, 104, 30))
    b.append(log(150, 150, 560, 86, 26))
    b.append(log(640, 152, 230, 92, 24))
    # andiron feet
    return svg("".join(b), defs, w, h)


def hearth_glow():
    # 960 x 540, shown at 2x over the whole screen; opacity breathes
    defs = """<radialGradient id="g" cx="480" cy="420" r="420" gradientUnits="userSpaceOnUse">
<stop offset="0" stop-color="#ff9a40" stop-opacity=".42"/><stop offset=".5" stop-color="#ff7a20" stop-opacity=".14"/><stop offset="1" stop-color="#ff7a20" stop-opacity="0"/></radialGradient>"""
    # keep the firebox itself clear so the sprite keeps its colour
    return svg('<rect width="960" height="540" fill="url(#g)"/>' +
               f'<path d="M{OPEN_L/2},{FLOOR/2} L{OPEN_L/2},{ARCH_CY/2} A{ARCH_RX/2},{ARCH_RY/2} 0 0 1 {OPEN_R/2},{ARCH_CY/2} L{OPEN_R/2},{FLOOR/2}Z" fill="#000" opacity="0"/>', defs, 960, 540)


# ---------------------------------------------------------------- rain
WIN_CX, WIN_CY, WIN_R = 960, 480, 330
OV = 420  # overlay half-size: overlay covers (WIN_CX-OV, WIN_CY-OV) .. +2*OV


def outside(ox=0, oy=0):
    """The rainy night through the window (drawn in screen coordinates, shifted by ox, oy)."""
    defs = """
<linearGradient id="sky" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#0d1a1a"/><stop offset=".6" stop-color="#1c302a"/><stop offset="1" stop-color="#22382c"/></linearGradient>
<filter id="haze"><feGaussianBlur stdDeviation="3.5"/></filter>
<filter id="lamp" x="-100%" y="-100%" width="300%" height="300%"><feGaussianBlur stdDeviation="10"/></filter>"""
    defs += f'<clipPath id="glassClip"><circle cx="{WIN_CX}" cy="{WIN_CY}" r="{WIN_R+6}"/></clipPath>'
    b = [f'<g transform="translate({ox},{oy})" clip-path="url(#glassClip)">', '<rect x="560" y="80" width="800" height="800" fill="url(#sky)"/>', '<g filter="url(#haze)">']
    b.append('<path d="M560,640 C700,560 820,600 960,560 C1100,520 1220,590 1360,560 L1360,880 L560,880Z" fill="#16241d"/>')
    b.append('<path d="M560,700 C680,660 780,700 900,672 C1040,640 1180,700 1360,660 L1360,880 L560,880Z" fill="#111c16"/>')
    # a hill with a lit round window across the way
    b.append('<path d="M1020,700 C1080,610 1240,600 1330,700Z" fill="#1a2a20"/>')
    b.append('<circle cx="1176" cy="668" r="13" fill="#f2b65a"/><circle cx="1176" cy="668" r="30" fill="#f2a040" opacity=".35" filter="url(#lamp)"/>')
    # a tree
    b.append('<path d="M700,720 L712,560 L724,720Z" fill="#0c1410"/><ellipse cx="712" cy="540" rx="80" ry="110" fill="#0e1a14"/><ellipse cx="680" cy="600" rx="60" ry="70" fill="#0d1712"/>')
    b.append('</g>')
    # garden near the window: dark leaves
    for i in range(26):
        x = 560 + R.uniform(0, 800); y = 820 + R.uniform(-30, 40)
        b.append(f'<ellipse cx="{x:.0f}" cy="{y:.0f}" rx="{R.uniform(30,70):.0f}" ry="{R.uniform(14,30):.0f}" fill="rgb({R.randint(12,20)},{R.randint(26,36)},{R.randint(18,24)})" transform="rotate({R.uniform(-30,30):.0f} {x:.0f} {y:.0f})"/>')
    b.append('</g>')
    return defs, "".join(b)


def rain_wall(hole):
    """Wall, window frame, sill and lamp glow. hole=True leaves the glass transparent."""
    defs = TEX.format(f="0.75", s=8, a="0.5") + """
<radialGradient id="lampglow" cx="260" cy="760" r="900" gradientUnits="userSpaceOnUse"><stop offset="0" stop-color="#ffb060" stop-opacity=".30"/><stop offset=".5" stop-color="#c06a28" stop-opacity=".10"/><stop offset="1" stop-color="#000" stop-opacity="0"/></radialGradient>
<radialGradient id="wallg" cx="50%" cy="45%" r="75%"><stop offset="0" stop-color="#1a2016"/><stop offset="1" stop-color="#090b07"/></radialGradient>
<linearGradient id="wood" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#5a3a20"/><stop offset=".5" stop-color="#3a2414"/><stop offset="1" stop-color="#22140a"/></linearGradient>
<radialGradient id="glass" cx="50%" cy="40%" r="60%"><stop offset="0" stop-color="#9ec0b0" stop-opacity=".06"/><stop offset="1" stop-color="#9ec0b0" stop-opacity=".0"/></radialGradient>
<filter id="dsoft"><feGaussianBlur stdDeviation="0.6"/></filter>
<filter id="sh" x="-20%" y="-20%" width="140%" height="140%"><feGaussianBlur stdDeviation="14"/></filter>
<mask id="glassHole"><rect width="1920" height="1080" fill="#fff"/><circle cx="WCX" cy="WCY" r="WR" fill="#000"/></mask>""".replace("WCX", str(WIN_CX)).replace("WCY", str(WIN_CY)).replace("WR", str(WIN_R))
    b = ['<g mask="url(#glassHole)">' if hole else '<g>']
    b.append('<rect width="1920" height="1080" fill="url(#wallg)"/>')
    b.append('<rect width="1920" height="1080" fill="#1a2016" filter="url(#tex)" opacity=".6"/>')
    b.append('<rect width="1920" height="1080" fill="url(#lampglow)"/>')
    # deep window reveal and its shadow
    b.append(f'<circle cx="{WIN_CX}" cy="{WIN_CY+10}" r="{WIN_R+70}" fill="#000" opacity=".45" filter="url(#sh)"/>')
    b.append(f'<circle cx="{WIN_CX}" cy="{WIN_CY}" r="{WIN_R+52}" fill="#2a2416"/>')
    # wooden ring
    b.append(f'<circle cx="{WIN_CX}" cy="{WIN_CY}" r="{WIN_R+34}" fill="url(#wood)"/>')
    b.append(f'<circle cx="{WIN_CX}" cy="{WIN_CY}" r="{WIN_R+34}" fill="#000" opacity=".35" filter="url(#tex)"/>')
    b.append(f'<circle cx="{WIN_CX}" cy="{WIN_CY}" r="{WIN_R+30}" fill="none" stroke="#7a5230" stroke-width="2" opacity=".5"/>')
    b.append(f'<circle cx="{WIN_CX}" cy="{WIN_CY}" r="{WIN_R+4}" fill="#120c06"/>')
    # glass area (when not a hole) is filled by the outside scene by the caller
    # muntins: a cross and an inner ring
    bx = WIN_R * 0.34
    hy = WIN_CY + WIN_R * 0.18
    def chord_y(x):  # vertical extent of the glass at x
        return math.sqrt(max(WIN_R ** 2 - (x - WIN_CX) ** 2, 0))
    def chord_x(y):
        return math.sqrt(max(WIN_R ** 2 - (y - WIN_CY) ** 2, 0))
    mun = '<g stroke="#3a2414" stroke-width="14" fill="none" stroke-linecap="butt">'
    for x in (WIN_CX - bx, WIN_CX + bx):
        e = chord_y(x)
        mun += f'<line x1="{x:.0f}" y1="{WIN_CY-e:.0f}" x2="{x:.0f}" y2="{WIN_CY+e:.0f}"/>'
    e = chord_x(hy)
    mun += f'<line x1="{WIN_CX-e:.0f}" y1="{hy:.0f}" x2="{WIN_CX+e:.0f}" y2="{hy:.0f}"/></g>'
    b.append('</g>')
    after = [mun]
    after.append(f'<g stroke="#6a4626" stroke-width="2" fill="none" opacity=".5">' + ''.join(f'<line x1="{x-5:.0f}" y1="{WIN_CY-chord_y(x)+6:.0f}" x2="{x-5:.0f}" y2="{WIN_CY+chord_y(x)-6:.0f}"/>' for x in (WIN_CX - bx, WIN_CX + bx)) + f'<line x1="{WIN_CX-chord_x(hy)+6:.0f}" y1="{hy-5:.0f}" x2="{WIN_CX+chord_x(hy)-6:.0f}" y2="{hy-5:.0f}"/></g>')
    # sill
    after.append(f'<path d="M{WIN_CX-300},{WIN_CY+WIN_R+40} L{WIN_CX+300},{WIN_CY+WIN_R+40} L{WIN_CX+330},{WIN_CY+WIN_R+76} L{WIN_CX-330},{WIN_CY+WIN_R+76}Z" fill="#3a2616"/>')
    after.append(f'<rect x="{WIN_CX-330}" y="{WIN_CY+WIN_R+76}" width="660" height="18" fill="#1e130a"/>')
    # a little pot plant and a candle on the sill
    px, py = WIN_CX - 210, WIN_CY + WIN_R + 44
    after.append(f'<path d="M{px-30},{py} L{px+30},{py} L{px+22},{py-46} L{px-22},{py-46}Z" fill="#5a3422" transform="translate(0,0)"/>')
    for k in range(9):
        a = -math.pi / 2 + R.uniform(-1.1, 1.1)
        L = R.uniform(40, 80)
        after.append(f'<path d="M{px},{py-46} q{math.cos(a)*L*0.3:.0f},{math.sin(a)*L*0.7:.0f} {math.cos(a)*L:.0f},{math.sin(a)*L:.0f}" stroke="#2c3e22" stroke-width="{R.uniform(5,9):.0f}" fill="none" stroke-linecap="round"/>')
    cx2 = WIN_CX + 230
    after.append(f'<circle cx="{cx2}" cy="{py-90}" r="120" fill="#ffb060" opacity=".16" filter="url(#sh)"/>')
    after.append(f'<rect x="{cx2-12}" y="{py-64}" width="24" height="64" rx="3" fill="#d8c9a0" opacity=".85"/>')
    after.append(f'<ellipse cx="{cx2}" cy="{py-78}" rx="6" ry="13" fill="#ffd27a"/><ellipse cx="{cx2}" cy="{py-74}" rx="2.5" ry="6" fill="#fff6dc"/>')
    return defs, "".join(b), "".join(after)


def droplets():
    out = []
    for i in range(140):
        a = R.uniform(0, 2 * math.pi); r = WIN_R * math.sqrt(R.random()) * 0.97
        x = WIN_CX + math.cos(a) * r; y = WIN_CY + math.sin(a) * r
        s = R.uniform(1.5, 4.5)
        out.append(f'<ellipse cx="{x:.1f}" cy="{y:.1f}" rx="{s:.1f}" ry="{s*1.2:.1f}" fill="#cfe2d8" opacity="{R.uniform(.10,.28):.2f}"/>')
        out.append(f'<circle cx="{x-s*0.3:.1f}" cy="{y-s*0.4:.1f}" r="{s*0.35:.1f}" fill="#fff" opacity="{R.uniform(.25,.5):.2f}"/>')
    for i in range(9):  # trails
        x = WIN_CX + R.uniform(-WIN_R * 0.8, WIN_R * 0.8)
        y0 = WIN_CY + R.uniform(-WIN_R * 0.6, WIN_R * 0.2)
        L = R.uniform(60, 180)
        out.append(f'<path d="M{x:.0f},{y0:.0f} q{R.uniform(-8,8):.0f},{L/2:.0f} {R.uniform(-6,6):.0f},{L:.0f}" stroke="#cfe2d8" stroke-width="2.5" opacity=".14" fill="none"/>')
        out.append(f'<ellipse cx="{x:.0f}" cy="{y0+L:.0f}" rx="4" ry="5" fill="#dfeee6" opacity=".3"/>')
    return "".join(out)


def rain_bg():
    d1, o = outside()
    d2, wall, after = rain_wall(False)
    glass = f'<circle cx="{WIN_CX}" cy="{WIN_CY}" r="{WIN_R}" fill="url(#glass)"/>'
    return svg(wall + o + glass + after, d1 + d2)


def rain_overlay():
    # crop of the wall around the window with the glass left clear; shown at (WIN_CX-OV, WIN_CY-OV)
    d2, wall, after = rain_wall(True)
    glass = f'<circle cx="{WIN_CX}" cy="{WIN_CY}" r="{WIN_R}" fill="url(#glass)"/>'
    body = f'<g transform="translate({-(WIN_CX-OV)},{-(WIN_CY-OV)})">' + wall + glass + droplets() + after + '</g>'
    return svg(body, d2, 2 * OV, 2 * OV)


def rain_streaks(seed, n, alpha, length, width):
    # a 2*OV square tile of slanted streaks that repeats vertically
    rr = random.Random(seed)
    s = 2 * OV
    b = []
    for i in range(n):
        x = rr.uniform(-40, s); y = rr.uniform(0, s); L = length * rr.uniform(0.6, 1.3)
        for dy in (0, -s, s):  # wrap so the tile repeats
            b.append(f'<line x1="{x:.0f}" y1="{y+dy:.0f}" x2="{x+L*0.12:.0f}" y2="{y+dy+L:.0f}" stroke="#c8dcd2" stroke-width="{width*rr.uniform(.7,1.2):.1f}" opacity="{alpha*rr.uniform(.5,1):.2f}" stroke-linecap="round"/>')
    return svg("".join(b), "", s, s)


# ---------------------------------------------------------------- fireflies
def night_bg():
    defs = """
<linearGradient id="nsky" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#05080a"/><stop offset=".55" stop-color="#0b1512"/><stop offset=".8" stop-color="#132219"/><stop offset="1" stop-color="#0a0f0a"/></linearGradient>
<radialGradient id="moon" cx="1500" cy="200" r="200" gradientUnits="userSpaceOnUse"><stop offset="0" stop-color="#d8dcc0" stop-opacity=".10"/><stop offset="1" stop-color="#d8dcc0" stop-opacity="0"/></radialGradient>
<filter id="nb"><feGaussianBlur stdDeviation="2.5"/></filter>
<filter id="mist"><feGaussianBlur stdDeviation="30"/></filter>
<filter id="lamp" x="-100%" y="-100%" width="300%" height="300%"><feGaussianBlur stdDeviation="16"/></filter>"""
    b = ['<rect width="1920" height="1080" fill="url(#nsky)"/>', '<rect width="1920" height="1080" fill="url(#moon)"/>']
    b.append('<mask id="cres"><rect width="1920" height="1080" fill="#fff"/><circle cx="1517" cy="190" r="36" fill="#000"/></mask>')
    b.append('<circle cx="1500" cy="200" r="38" fill="#e6e4c8" opacity=".85" mask="url(#cres)"/>')
    for i in range(160):
        x = R.uniform(0, 1920); y = R.uniform(0, 560)
        b.append(f'<circle cx="{x:.0f}" cy="{y:.0f}" r="{R.uniform(.6,1.6):.1f}" fill="#e8e6d0" opacity="{R.uniform(.15,.6):.2f}"/>')
    # far hills
    b.append('<path d="M0,640 C240,560 420,600 640,580 C900,550 1100,620 1380,570 C1600,535 1780,590 1920,560 L1920,1080 L0,1080Z" fill="#0f1a15" filter="url(#nb)"/>')
    b.append('<rect x="0" y="600" width="1920" height="120" fill="#2a3a30" opacity=".25" filter="url(#mist)"/>')
    # the hill with a round door and a lit window
    b.append('<path d="M180,760 C380,560 760,560 980,760Z" fill="#132017"/>')
    b.append('<circle cx="560" cy="700" r="46" fill="#0a0f0a"/><circle cx="560" cy="700" r="40" fill="#2a3a22"/><circle cx="574" cy="702" r="4" fill="#b08a40"/>')
    b.append('<circle cx="680" cy="690" r="16" fill="#f2b65a"/><circle cx="680" cy="690" r="40" fill="#f2a040" opacity=".35" filter="url(#lamp)"/>')
    b.append('<path d="M520,620 l6,-40 l14,0 l6,40Z" fill="#0d150f"/>')  # chimney
    # trees on the right
    for x, s in [(1300, 1.0), (1420, 1.25), (1560, 0.9), (1720, 1.15)]:
        b.append(f'<rect x="{x-6}" y="{770-120*s:.0f}" width="12" height="{120*s:.0f}" fill="#0a120d"/>')
        for k in range(5):
            b.append(f'<path d="{blob(x + R.uniform(-30,30)*s, 770 - (150 + k*38)*s, (70 - k*9)*s, (52 - k*5)*s, 0.18, 9)}" fill="rgb({R.randint(11,15)},{R.randint(22,27)},{R.randint(17,20)})"/>')
    # midground meadow
    b.append('<path d="M0,760 C320,720 640,760 960,740 C1280,720 1600,760 1920,730 L1920,1080 L0,1080Z" fill="#0d160f"/>')
    b.append('<rect x="0" y="720" width="1920" height="90" fill="#33463a" opacity=".22" filter="url(#mist)"/>')
    # foreground grass and ferns, in silhouette
    for i in range(420):
        x = R.uniform(-20, 1940); base = 1080 + R.uniform(0, 20)
        h = R.uniform(90, 300) * (1.2 if (x < 300 or x > 1620) else 0.8)
        bend = R.uniform(-60, 60)
        g = R.randint(10, 22)
        b.append(f'<path d="M{x:.0f},{base:.0f} q{bend*0.3:.0f},{-h*0.6:.0f} {bend:.0f},{-h:.0f} q{-bend*0.2:.0f},{h*0.5:.0f} {-bend*0.6+6:.0f},{h:.0f}Z" fill="rgb({g-4},{g+6},{g-2})"/>')
    return svg("".join(b), defs)


if __name__ == "__main__":
    od = sys.argv[1]
    os.makedirs(od, exist_ok=True)
    files = {
        "hearth-bg.svg": hearth_bg(), "hearth-logs.svg": hearth_logs(), "hearth-glow.svg": hearth_glow(),
        "rain-bg.svg": rain_bg(), "rain-window.svg": rain_overlay(),
        "rain-far.svg": rain_streaks(1, 130, 0.22, 60, 1.6), "rain-near.svg": rain_streaks(2, 45, 0.32, 120, 2.6),
        "night-bg.svg": night_bg(),
    }
    for k, v in files.items():
        open(os.path.join(od, k), "w").write(v)
    print("wrote", len(files))
