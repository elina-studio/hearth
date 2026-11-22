# Shades for the slideshow so the clock and captions stay readable on bright photos.
# Run: python3 tools/make-photo-shades.py
from PIL import Image
import math

def smooth(a):
    a = max(0.0, min(1.0, a))
    return a * a * (3 - 2 * a)

# top right: clock, date, weather (drawn at half size, shown at 1100x640)
w, h = 550, 320
im = Image.new("RGBA", (w, h))
px = im.load()
for y in range(h):
    for x in range(w):
        d = math.hypot((w - x) / (w * 0.75), y / (h * 0.85))
        px[x, y] = (6, 8, 5, int(232 * smooth(1.0 - d / 1.0) ** 0.8))
im.save("images/photo-shade-tr.png", optimize=True)

# bottom: album, date, now playing (a 1-px-wide strip, stretched to 1920x360)
w, h = 4, 180
im = Image.new("RGBA", (w, h))
px = im.load()
for y in range(h):
    for x in range(w):
        px[x, y] = (6, 8, 5, int(192 * smooth(y / (h - 1))))
im.save("images/photo-shade-bottom.png", optimize=True)
