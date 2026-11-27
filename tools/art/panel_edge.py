"""The hand-cut right edge of the Music room's left panel (components/music/MusicNowPanel, column layout).
A white strip 24 px wide and 930 tall: solid on its left, uneven on its right. The app tints it like the panel.
Run: python3 tools/art/panel_edge.py   (writes images/w/rough/panel-edge.png)"""
import math
import random
from PIL import Image, ImageDraw

W, H, SS = 24, 930, 4


def profile(seed, n):
    """How far the edge sits in from the strip's right side (2..20 px) at each px down: long lazy wanders with a few nicks."""
    r = random.Random(seed)
    knots = [(0, 10.0)]
    y = 0
    while y < n - 30:
        y += r.randint(14, 46)
        v = r.uniform(5, 15)
        if r.random() < 0.22:
            v = r.choice([r.uniform(2, 4), r.uniform(17, 20)])
        knots.append((y, v))
    knots.append((n - 1, 10.0))
    p, k = [], 0
    for i in range(n):
        while knots[k + 1][0] < i:
            k += 1
        (y0, v0), (y1, v1) = knots[k], knots[k + 1]
        t = (i - y0) / max(1, y1 - y0)
        t = (1 - math.cos(t * math.pi)) / 2
        p.append(v0 + (v1 - v0) * t)
    return p


def mask():
    im = Image.new("L", (W * SS, H * SS), 0)
    pts = [((W - o) * SS, (i + 0.5) * SS) for i, o in enumerate(profile(7, H))]
    ImageDraw.Draw(im).polygon([(0, 0)] + pts + [(0, H * SS)], fill=255)
    return im.resize((W, H), Image.LANCZOS)


if __name__ == "__main__":
    out = Image.new("RGBA", (W, H), (255, 255, 255, 0))
    out.putalpha(mask())
    out.save("images/w/rough/panel-edge.png")
    print("wrote images/w/rough/panel-edge.png")
