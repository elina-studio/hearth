# Corner shades for the slideshow so the clock and captions stay readable on bright photos.
# Run: python3 tools/make-photo-shades.py
from PIL import Image
import math

def shade(w, h, cx, cy, rx, ry, alpha, path):
    im = Image.new("RGBA", (w, h))
    px = im.load()
    for y in range(h):
        for x in range(w):
            d = math.hypot((x - cx) / rx, (y - cy) / ry)
            a = max(0.0, 1.0 - d)
            a = a * a * (3 - 2 * a)  # smoothstep
            px[x, y] = (6, 8, 5, int(alpha * a))
    im.save(path, optimize=True)

# top right: clock, date, weather (drawn at 960x540, shown at 2x)
shade(480, 300, 480, 0, 470, 300, 200, "images/photo-shade-tr.png")
# bottom left: album and when/where the photo was taken
shade(480, 200, 0, 200, 470, 200, 190, "images/photo-shade-bl.png")
