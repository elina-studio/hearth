"""Rough-edged card pieces for Hearth popups (components/ui/RoughCard).
A card of any size is put together on the TV from: four corners (40x40), edge strips (160 long, 16 deep) laid
end to end, and a plain rectangle in the middle. Every piece is white so the app tints it; each has a "fill"
and a "line" version (the line is the 2 px edge alone, drawn in gold over the fill).
Run: python3 tools/art/rough_card.py   (writes images/w/rough/*.png; the same code draws mockup cards)"""
import random
from PIL import Image, ImageDraw

D = 16          # depth of an edge strip
L = 160         # length of an edge strip
C = 40          # corner size
SS = 4          # supersample

def profile(seed, n):
    """Edge offsets (0..8 px inward) for each px along n px: a hand-cut edge, uneven but straight overall.
    0 at both ends so strips and corners join cleanly."""
    import math
    r = random.Random(seed)
    knots = [(0, 0.0)]
    x = 0
    while x < n - 22:
        x += r.randint(8, 20)
        v = r.choice([0.5, 1.5, 2.5, 3.5, 4.5, 3, 1, 0.5, 2])
        if r.random() < 0.2: v = r.uniform(6, 8)
        knots.append((x, v))
    knots.append((n - 1, 0.0))
    p = []
    k = 0
    for i in range(n):
        while knots[k + 1][0] < i: k += 1
        (x0, v0), (x1, v1) = knots[k], knots[k + 1]
        t = (i - x0) / max(1, x1 - x0)
        t = (1 - math.cos(t * math.pi)) / 2
        p.append(v0 + (v1 - v0) * t)
    return p

P = {"top": profile(11, L), "bottom": profile(23, L), "left": profile(37, L), "right": profile(41, L)}

def strip(side, kind):
    horiz = side in ("top", "bottom")
    w, h = (L, D) if horiz else (D, L)
    im = Image.new("L", (w * SS, h * SS), 0)
    d = ImageDraw.Draw(im)
    pts = []
    for i, o in enumerate(P[side]):
        a = (i + 0.5) * SS
        b = o * SS
        if side == "top": pts.append((a, b))
        if side == "bottom": pts.append((a, h * SS - b))
        if side == "left": pts.append((b, a))
        if side == "right": pts.append((w * SS - b, a))
    if kind == "fill":
        far = {"top": [(w * SS, h * SS), (0, h * SS)], "bottom": [(w * SS, 0), (0, 0)],
               "left": [(w * SS, h * SS), (w * SS, 0)], "right": [(0, h * SS), (0, 0)]}[side]
        first = {"top": (0, 0), "bottom": (0, h * SS), "left": (0, 0), "right": (w * SS, 0)}[side]
        last = {"top": (w * SS, 0), "bottom": (w * SS, h * SS), "left": (0, h * SS), "right": (w * SS, h * SS)}[side]
        d.polygon([first] + pts + [last] + far, fill=255)
    else:
        first = {"top": (0, 0), "bottom": (0, h * SS), "left": (0, 0), "right": (w * SS, 0)}[side]
        last = {"top": (w * SS, 0), "bottom": (w * SS, h * SS), "left": (0, h * SS), "right": (w * SS, h * SS)}[side]
        d.line([first] + pts + [last], fill=255, width=2 * SS, joint="curve")
    return im.resize((w, h), Image.LANCZOS)

def corner(which, kind):
    """A rounded corner; its two open ends meet the edges at offset 0."""
    im = Image.new("L", (C * SS, C * SS), 0)
    d = ImageDraw.Draw(im)
    R = 20 * SS
    if kind == "fill":
        d.rounded_rectangle([0, 0, C * SS * 2, C * SS * 2], radius=R, fill=255)
    else:
        d.rounded_rectangle([SS - 1, SS - 1, C * SS * 2, C * SS * 2], radius=R, outline=255, width=2 * SS)
    im = im.resize((C, C), Image.LANCZOS)
    if which in ("tr", "br"): im = im.transpose(Image.FLIP_LEFT_RIGHT)
    if which in ("bl", "br"): im = im.transpose(Image.FLIP_TOP_BOTTOM)
    return im

def white(mask):
    out = Image.new("RGBA", mask.size, (255, 255, 255, 0))
    out.putalpha(mask)
    return out

def pieces():
    out = {}
    for kind in ("fill", "line"):
        for s in ("top", "bottom", "left", "right"): out[f"{s}-{kind}"] = white(strip(s, kind))
        for c in ("tl", "tr", "bl", "br"): out[f"{c}-{kind}"] = white(corner(c, kind))
    return out

def runs(total):
    """Strip positions along one side, and the straight stretch left over at each end (after the corner)."""
    n = (total - 2 * C) // L
    pad = (total - 2 * C - n * L) // 2
    return [C + pad + i * L for i in range(n)], pad

def card(w, h, fill=(20, 26, 17, 255), line=(224, 179, 74, 120)):
    """A whole card as one picture, for mockups. RoughCard.brs lays the same pieces out the same way."""
    pc = pieces()
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    dr = ImageDraw.Draw(out)
    def tint(im, col):
        t = Image.new("RGBA", im.size, col[:3] + (0,))
        t.putalpha(im.getchannel("A").point(lambda a: a * col[3] // 255))
        return t
    def put(name, x, y):
        out.alpha_composite(tint(pc[name + "-fill"], fill), (x, y))
        lines.append((name, x, y))
    lines = []
    dr.rectangle([D, D, w - D - 1, h - D - 1], fill=fill)
    for c, x, y in (("tl", 0, 0), ("tr", w - C, 0), ("bl", 0, h - C), ("br", w - C, h - C)): put(c, x, y)
    xs, padx = runs(w)
    ys, pady = runs(h)
    for x in xs:
        put("top", x, 0); put("bottom", x, h - D)
    for y in ys:
        put("left", 0, y); put("right", w - D, y)
    # the straight stretches beside each corner, and what the strips do not cover inside the corners' depth
    for x0, x1 in ((C, C + padx), (w - C - padx - (w - 2 * C - len(xs) * L - 2 * padx), w - C)):
        if x1 > x0:
            dr.rectangle([x0, 0, x1 - 1, D - 1], fill=fill); dr.rectangle([x0, h - D, x1 - 1, h - 1], fill=fill)
    for y0, y1 in ((C, C + pady), (h - C - pady - (h - 2 * C - len(ys) * L - 2 * pady), h - C)):
        if y1 > y0:
            dr.rectangle([0, y0, D - 1, y1 - 1], fill=fill); dr.rectangle([w - D, y0, w - 1, y1 - 1], fill=fill)
    dr.rectangle([D, D, w - D - 1, C], fill=fill); dr.rectangle([D, h - C - 1, w - D - 1, h - D - 1], fill=fill)
    top = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    td = ImageDraw.Draw(top)
    for name, x, y in lines: top.alpha_composite(tint(pc[name + "-line"], line), (x, y))
    for x0, x1 in ((C, C + padx), (C + padx + len(xs) * L, w - C)):
        if x1 > x0:
            td.rectangle([x0, 0, x1 - 1, 1], fill=line); td.rectangle([x0, h - 2, x1 - 1, h - 1], fill=line)
    for y0, y1 in ((C, C + pady), (C + pady + len(ys) * L, h - C)):
        if y1 > y0:
            td.rectangle([0, y0, 1, y1 - 1], fill=line); td.rectangle([w - 2, y0, w - 1, y1 - 1], fill=line)
    out.alpha_composite(top)
    return out

if __name__ == "__main__":
    import os
    here = os.path.join(os.path.dirname(__file__), "..", "..", "images", "w", "rough")
    os.makedirs(here, exist_ok=True)
    for name, im in pieces().items(): im.save(os.path.join(here, name + ".png"))
    print("wrote", len(pieces()), "pieces")
