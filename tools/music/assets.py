# Visualizer art for the Music room: white rings on transparent, tinted on the TV with blendColor.
# python3 tools/music/assets.py   (writes into images/music)
import numpy as np, wave
from PIL import Image, ImageDraw, ImageFilter
rng = np.random.default_rng(3)

# ---- visualizer rings: white on transparent so blendColor tints them ----
S = 1024
def ring_img(draw_fn, blur):
    im = Image.new("L", (S, S), 0); dd = ImageDraw.Draw(im); draw_fn(dd)
    a = im.filter(ImageFilter.GaussianBlur(blur))
    out = Image.new("RGBA", (S, S), (255, 255, 255, 0)); out.putalpha(a); return out
c = S / 2
def rosette(dd):
    for k in range(12):
        a = k * np.pi / 6
        for rr in range(60, 470, 3):
            w = 70 * np.sin(np.pi * (rr - 60) / 410) ** 1.5
            for s in (-1, 1):
                ang = a + s * w / max(rr, 1)
                x, y = c + rr * np.cos(ang), c + rr * np.sin(ang)
                dd.ellipse([x - 2, y - 2, x + 2, y + 2], fill=210)
def spiral(dd):
    for k in range(8):
        pts = []
        for t in np.linspace(0, 3.2, 400):
            rr = 30 * np.exp(0.86 * t); ang = k * np.pi / 4 + t
            if rr > 500: break
            pts.append((c + rr * np.cos(ang), c + rr * np.sin(ang)))
        dd.line(pts, fill=255, width=7)
def dots(dd):
    for ring in range(1, 9):
        rr = ring * 56; n = 6 * ring
        for k in range(n):
            ang = 2 * np.pi * k / n + ring * 0.3
            x, y = c + rr * np.cos(ang), c + rr * np.sin(ang); s = 6 + ring
            dd.ellipse([x - s, y - s, x + s, y + s], fill=255)
ring_img(rosette, 3).save("images/music/viz-rosette.png", optimize=True)
ring_img(spiral, 4).save("images/music/viz-spiral.png", optimize=True)
ring_img(dots, 3).save("images/music/viz-dots.png", optimize=True)

