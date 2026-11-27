"""The hand-cut bottom edge of the top bar (HubScreen topShade, details RoomBar).
A white strip 1920 wide and 20 tall: solid on top, uneven along the bottom. The app tints it the bar's colour.
Run: python3 tools/art/header_edge.py   (writes images/w/rough/header-edge.png)"""
import math
import random
from PIL import Image, ImageDraw

W, H, SS = 1920, 20, 4


def profile(seed, n):
    """How far the edge hangs below the bar (1..16 px) at each px across: long lazy wanders with a few nicks."""
    r = random.Random(seed)
    knots = [(0, 7.0)]
    x = 0
    while x < n - 40:
        x += r.randint(18, 60)
        v = r.uniform(4, 11)
        if r.random() < 0.2:
            v = r.choice([r.uniform(1, 3), r.uniform(13, 16)])
        knots.append((x, v))
    knots.append((n - 1, 7.0))
    p, k = [], 0
    for i in range(n):
        while knots[k + 1][0] < i:
            k += 1
        (x0, v0), (x1, v1) = knots[k], knots[k + 1]
        t = (i - x0) / max(1, x1 - x0)
        t = (1 - math.cos(t * math.pi)) / 2
        p.append(v0 + (v1 - v0) * t)
    return p


def mask():
    im = Image.new("L", (W * SS, H * SS), 0)
    pts = [((i + 0.5) * SS, o * SS) for i, o in enumerate(profile(19, W))]
    ImageDraw.Draw(im).polygon([(0, 0)] + [(0, pts[0][1])] + pts + [(W * SS, pts[-1][1]), (W * SS, 0)], fill=255)
    return im.resize((W, H), Image.LANCZOS)


if __name__ == "__main__":
    out = Image.new("RGBA", (W, H), (255, 255, 255, 0))
    out.putalpha(mask())
    out.save("images/w/rough/header-edge.png")
    print("wrote images/w/rough/header-edge.png")
