"""Hearth fire: 48 seamlessly looping frames in one 8 x 6 sheet (240 x 180 each).

    python3 tools/ambiance/fire.py out.jpg [preview.gif]

The sheet is shown 3x on the TV, flipped by a timer at 12 fps (4 s loop).
Each frame's border fades to the firebox colour FIREBOX so it sits seamlessly in the painted opening.
"""
import sys
import numpy as np
from PIL import Image

FW, FH, COLS, ROWS = 240, 180, 8, 6
N = COLS * ROWS
FIREBOX = np.array([17, 11, 7], float)
rng = np.random.default_rng(11)


class Lattice:
    """Value noise, periodic in x (px) and y (py)."""
    def __init__(self, px, py):
        self.g = rng.random((py, px))
        self.px, self.py = px, py

    def __call__(self, x, y):
        x0 = np.floor(x).astype(int); y0 = np.floor(y).astype(int)
        fx = x - x0; fy = y - y0
        fx = fx * fx * (3 - 2 * fx); fy = fy * fy * (3 - 2 * fy)
        g = self.g
        def at(i, j):
            return g[j % self.py, i % self.px]
        a = at(x0, y0) * (1 - fx) + at(x0 + 1, y0) * fx
        b = at(x0, y0 + 1) * (1 - fx) + at(x0 + 1, y0 + 1) * fx
        return a * (1 - fy) + b * fy


# octaves: (x cells per frame width, y cells per frame height, lattice y period, loops per cycle, weight)
OCT = [(5, 4, 16, 2, 0.55), (10, 8, 32, 4, 0.28), (20, 16, 64, 8, 0.17)]
lat = [Lattice(o[0] * 4, o[2]) for o in OCT]
warp = Lattice(24, 16)

H, W = FH, FW
v = (1 - (np.arange(H) + 0.5) / H)[:, None] * np.ones((1, W))  # 0 at bottom
u = np.ones((H, 1)) * ((np.arange(W) + 0.5) / W)[None, :]

TONGUES = [  # centre, width, base height, wobble amp, cycles per loop, phase
    (0.50, 0.11, 0.80, 0.10, 1, 0.0),
    (0.40, 0.09, 0.62, 0.12, 2, 1.3),
    (0.60, 0.09, 0.66, 0.12, 1, 2.6),
    (0.31, 0.07, 0.42, 0.10, 3, 0.7),
    (0.69, 0.07, 0.46, 0.10, 2, 4.0),
    (0.46, 0.06, 0.52, 0.14, 3, 5.1),
    (0.55, 0.06, 0.55, 0.14, 2, 3.3),
]

STOPS = [(0.00, FIREBOX), (0.08, [70, 16, 6]), (0.24, [160, 40, 10]), (0.45, [228, 96, 20]),
         (0.66, [250, 150, 44]), (0.86, [255, 204, 110]), (1.00, [255, 236, 186])]


def colormap(i):
    out = np.zeros(i.shape + (3,))
    for (a, ca), (b, cb) in zip(STOPS, STOPS[1:]):
        m = (i >= a) & (i <= b)
        t = ((i - a) / (b - a))[m][:, None]
        out[m] = np.array(ca) * (1 - t) + np.array(cb) * t
    out[i > 1] = STOPS[-1][1]
    return out


def blur(img, sigma):
    h, w = img.shape
    fy = np.fft.fftfreq(h)[:, None]; fx = np.fft.fftfreq(w)[None, :]
    g = np.exp(-2 * (np.pi * sigma) ** 2 * (fx ** 2 + fy ** 2))
    pad = np.pad(img, ((h // 2, h // 2), (w // 2, w // 2)))
    H2, W2 = pad.shape
    fy = np.fft.fftfreq(H2)[:, None]; fx = np.fft.fftfreq(W2)[None, :]
    g = np.exp(-2 * (np.pi * sigma) ** 2 * (fx ** 2 + fy ** 2))
    r = np.real(np.fft.ifft2(np.fft.fft2(pad) * g))
    return r[h // 2:h // 2 + h, w // 2:w // 2 + w]


def frame(k):
    ph = k / N
    # turbulence scrolling upward; each octave makes whole lattice loops per cycle
    n = np.zeros((H, W))
    for (cx, cy, py, loops, wt), L in zip(OCT, lat):
        n += wt * L(u * cx, v * cy - ph * py * loops)
    wx = warp(u * 6, v * 4 - ph * 16 * 3) - 0.5
    uu = u + wx * 0.09 * (0.25 + v)
    base = np.zeros((H, W))
    for c, w0, h0, amp, cyc, p0 in TONGUES:
        h = h0 + amp * np.sin(2 * np.pi * cyc * ph + p0)
        cx = c + 0.015 * np.sin(2 * np.pi * cyc * ph + p0 * 1.7)
        w = w0 * (1.0 + 0.6 * (1 - v))  # wider at the bottom
        col = np.exp(-((uu - cx) / w) ** 2)
        hgt = np.clip(1 - v / max(h, 0.05), 0, 1) ** 0.75
        base = np.maximum(base, col * hgt)
    # ember bed behind the logs
    bed = np.exp(-((u - 0.5) / 0.27) ** 6) * np.clip(1 - v / 0.14, 0, 1)
    base = np.maximum(base, bed * 0.85)
    i = base * 1.05 - (n - 0.38) * 1.25 * (0.22 + v)
    i = np.clip(i, 0, None)
    i = np.clip((i - 0.2) / 0.78, 0, 1.0) ** 1.15
    # a little ember speckle low down
    rgb = colormap(np.minimum(i, 1.0))
    # warm light in the firebox around the flames
    glow = blur(np.minimum(i, 1), 14) * 1.4
    gcol = np.array([150, 52, 14])
    rgb = rgb + (1 - np.clip(i * 3, 0, 1))[..., None] * glow[..., None] * (gcol - FIREBOX)
    # fade the frame edge to the firebox colour
    ex = np.minimum(u, 1 - u) / 0.12
    ey_top = (1 - (1 - v)) * 0 + (1 - v) / 0.10  # distance from top edge
    ey_bot = v / 0.03
    edge = np.clip(np.minimum(np.minimum(ex, ey_top), ey_bot), 0, 1)
    edge = edge * edge * (3 - 2 * edge)
    rgb = FIREBOX + (rgb - FIREBOX) * edge[..., None]
    return np.clip(rgb, 0, 255).astype(np.uint8)


if __name__ == "__main__":
    out = sys.argv[1]
    sheet = Image.new("RGB", (FW * COLS, FH * ROWS))
    frames = []
    for k in range(N):
        f = Image.fromarray(frame(k))
        frames.append(f)
        sheet.paste(f, ((k % COLS) * FW, (k // COLS) * FH))
    sheet.save(out, quality=88, subsampling=0)
    if len(sys.argv) > 2:
        big = [f.resize((FW * 3, FH * 3), Image.BILINEAR) for f in frames]
        big[0].save(sys.argv[2], save_all=True, append_images=big[1:] * 2, duration=83, loop=0)
    print("wrote", out)
