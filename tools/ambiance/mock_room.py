"""Preview of the Ambiance room layout (matches AmbianceRoom.brs).  python3 mock_room.py out.png [index]"""
import sys
from PIL import Image, ImageDraw, ImageFont
idx = int(sys.argv[2]) if len(sys.argv) > 2 else 0
H, WIDE, RULE = 930, 760, 14
items = [("HEARTH", "A log fire, crackling", "hearth"), ("RAIN", "On the glass, after dark", "rain"), ("FIREFLIES", "A summer night outside", "fireflies"), ("LIGHTS OUT", "Embers, then dark in 30 min", "lightsout"), ("THE WINDOW", "Your photos", "window")]
n = len(items); narrow = (1920 - WIDE - (n - 1) * RULE) // (n - 1)
im = Image.new("RGB", (1920, 1080), (11, 14, 9)); d = ImageDraw.Draw(im)
caps = ImageFont.truetype("fonts/BarlowCondensed-Bold.ttf", 64); fell = ImageFont.truetype("fonts/IMFellEnglish-Italic.ttf", 30)
ui = ImageFont.truetype("fonts/AtkinsonHyperlegible-Bold.ttf", 26)
x = 0; y0 = 150
weave = Image.open("images/amb/weave.png")
shade = Image.new("L", (1, 520)); [shade.putpixel((0, k), int(235 * (k / 519) ** 1.4)) for k in range(520)]
for i, (t, s, m) in enumerate(items):
    w = WIDE if i == idx else narrow
    p = Image.open(f"images/amb/col-{m}.jpg").crop(((WIDE - w) // 2, 0, (WIDE - w) // 2 + w, H))
    if i != idx: p = Image.blend(p, Image.new("RGB", p.size, (11, 14, 9)), 0.38)
    im.paste(p, (x, y0))
    sh = shade.resize((w, 520)); im.paste(Image.new("RGB", (w, 520), (0, 0, 0)), (x, y0 + H - 520), sh)
    col = (224, 179, 74) if i == idx else (237, 230, 202)
    lines = [t] if d.textlength(t, font=caps) <= w - 50 else t.split(" ", 1)
    yy = y0 + H - 90 - 64 * len(lines)
    for L in lines:
        d.text((x + 28, yy), L, font=caps, fill=col); yy += 64
    if w > narrow + 200: d.text((x + 30, y0 + H - 78), s, font=fell, fill=(181, 175, 140))
    if i == idx: d.rectangle((x, y0 + H - 6, x + w, y0 + H), fill=(224, 179, 74))
    x += w
    if i < n - 1:
        im.paste(weave, (x, y0), weave); x += RULE
# pill bar stand-in
pills = ["Home", "Movies", "Shows", "Music", "Requests", "Ambiance", "Photos", "Search"]
px = 164
for p in pills:
    tw = d.textlength(p, font=ui) + 48
    if p == "Ambiance": d.rounded_rectangle((px, 57, px + tw, 105), 24, outline=(224, 179, 74), width=3)
    d.text((px + 24, 66), p, font=ui, fill=(237, 230, 202)); px += tw + 8
im.save(sys.argv[1])
