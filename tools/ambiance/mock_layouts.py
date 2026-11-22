"""Three Ambiance room layout options as 1920x1080 TV frames.  python3 mock_layouts.py out_dir"""
import sys, os, math
from PIL import Image, ImageDraw, ImageFont, ImageFilter
F = "fonts/"
caps = lambda s: ImageFont.truetype(F + "BarlowCondensed-Bold.ttf", s)
fell = lambda s: ImageFont.truetype(F + "IMFellEnglish-Italic.ttf", s)
ui = lambda s: ImageFont.truetype(F + "AtkinsonHyperlegible-Bold.ttf", s)
uir = lambda s: ImageFont.truetype(F + "AtkinsonHyperlegible-Regular.ttf", s)
INK, MUTED, GOLD, NIGHT = (237, 230, 202), (181, 175, 140), (224, 179, 74), (11, 14, 9)
MOODS = [("HEARTH", "A log fire, crackling", "hearth"), ("RAIN", "On the glass, after dark", "rain"),
         ("FIREFLIES", "A summer night outside", "fireflies"), ("LIGHTS OUT", "Embers, then dark in 30 min", "lightsout"),
         ("THE WINDOW", "Your photos", "window")]
weave = Image.open("images/amb/weave.png")
full = {"hearth": "/mnt/project-files/hearth/ambiance/hearth-preview.jpg", "rain": "/mnt/project-files/hearth/ambiance/rain-preview.jpg",
        "fireflies": "/mnt/project-files/hearth/ambiance/night-preview.jpg"}


def pic(mood, w, h):
    """The mood picture cropped to fill w x h (placeholder art until the person's clips arrive)."""
    if mood in full:
        im = Image.open(full[mood]).convert("RGB")
    else:
        im = Image.open(f"images/amb/col-{mood}.jpg").convert("RGB")
    sc = max(w / im.width, h / im.height)
    im = im.resize((int(im.width * sc) + 1, int(im.height * sc) + 1), Image.LANCZOS)
    x0 = (im.width - w) // 2; y0 = (im.height - h) // 2
    return im.crop((x0, y0, x0 + w, y0 + h))


def shade(w, h, top=False, strength=235):
    m = Image.new("L", (1, h))
    for k in range(h):
        t = k / (h - 1)
        if top: t = 1 - t
        m.putpixel((0, k), int(strength * t ** 1.4))
    return m.resize((w, h))


def frame():
    im = Image.new("RGB", (1920, 1080), NIGHT)
    d = ImageDraw.Draw(im)
    px = 164
    f = ui(26)
    # lantern dot stand-in
    d.ellipse((100, 62, 136, 98), outline=GOLD, width=3)
    for p in ["Home", "Movies", "Shows", "Music", "Requests", "Ambiance", "Photos", "Search"]:
        tw = d.textlength(p, font=f) + 48
        if p == "Ambiance": d.rounded_rectangle((px, 57, px + tw, 105), 24, outline=GOLD, width=3)
        d.text((px + 24, 66), p, font=f, fill=INK); px += tw + 8
    d.text((1824 - d.textlength("5:19", font=ui(40)), 52), "5:19", font=ui(40), fill=INK)
    return im, d


# ---- remote key icons -------------------------------------------------------------
def key(d, x, y, kind, label=None, h=40):
    """Draw a remote-key chip and an optional label; returns the x after it."""
    r = h // 2
    cx, cy = x + r, y + r
    if kind == "ok":
        w = 58
        d.rounded_rectangle((x, y, x + w, y + h), r, outline=INK, width=2)
        d.text((x + w / 2, cy), "OK", font=ui(18), fill=INK, anchor="mm"); x2 = x + w
    else:
        d.ellipse((x, y, x + h, y + h), outline=INK, width=2); x2 = x + h
        if kind in ("left", "right", "up", "down"):
            a = {"right": 0, "down": 90, "left": 180, "up": 270}[kind]
            pts = [(cx + 9 * math.cos(math.radians(a + t)), cy + 9 * math.sin(math.radians(a + t))) for t in (0, 140, 220)]
            d.polygon(pts, fill=INK)
        elif kind == "star":
            for t in range(0, 180, 60):
                dx, dy = 9 * math.cos(math.radians(t)), 9 * math.sin(math.radians(t))
                d.line((cx - dx, cy - dy, cx + dx, cy + dy), fill=INK, width=3)
        elif kind == "back":
            d.arc((cx - 9, cy - 8, cx + 9, cy + 10), 270, 180, fill=INK, width=3)
            d.polygon([(cx - 12, cy - 6), (cx - 4, cy - 13), (cx - 4, cy + 1)], fill=INK)
        elif kind == "play":
            d.polygon([(cx - 6, cy - 9), (cx - 6, cy + 9), (cx + 9, cy)], fill=INK)
    if label:
        d.text((x2 + 12, cy), label, font=uir(24), fill=MUTED, anchor="lm")
        x2 = x2 + 12 + d.textlength(label, font=uir(24))
    return x2 + 30


def speaker(d, x, y, on=True, col=GOLD):
    d.polygon([(x, y + 10), (x + 9, y + 10), (x + 20, y), (x + 20, y + 32), (x + 9, y + 22), (x, y + 22)], fill=col)
    if on:
        d.arc((x + 18, y + 6, x + 32, y + 26), 300, 60, fill=col, width=3)
        d.arc((x + 18, y, x + 42, y + 32), 300, 60, fill=col, width=3)


def hints(d, y, items, right=1824):
    # measure then draw right-aligned
    tmp = Image.new("RGB", (10, 10)); td = ImageDraw.Draw(tmp)
    w = 0
    for k, l in items:
        w = key(td, w, 0, k, l) if True else w
    x = right - w + 30
    for k, l in items:
        x = key(d, x, y, k, l)


# ---- A: five columns, focused widens -----------------------------------------------
def option_a(idx=1):
    im, d = frame()
    H, WIDE, RULE, y0 = 930, 760, 14, 150
    n = 5; narrow = (1920 - WIDE - (n - 1) * RULE) // (n - 1)
    x = 0
    for i, (t, s, m) in enumerate(MOODS):
        w = WIDE if i == idx else narrow
        p = pic(m, w, H)
        if i != idx: p = Image.blend(p, Image.new("RGB", p.size, NIGHT), 0.4)
        im.paste(p, (x, y0)); im.paste(Image.new("RGB", (w, 520), 0), (x, y0 + H - 520), shade(w, 520))
        col = GOLD if i == idx else INK
        lines = [t] if d.textlength(t, font=caps(64)) <= w - 50 else t.split(" ", 1)
        yy = y0 + H - 92 - 64 * len(lines)
        for L in lines: d.text((x + 28, yy), L, font=caps(64), fill=col); yy += 64
        if i == idx:
            d.text((x + 30, y0 + H - 80), s, font=fell(30), fill=MUTED)
            speaker(d, x + w - 62, y0 + 30)
            key(d, x + w - 200, y0 + H - 84, "ok", "Open")
            d.rectangle((x, y0 + H - 6, x + w, y0 + H), fill=GOLD)
        x += w
        if i < n - 1: im.paste(weave, (x, y0), weave); x += RULE
    return im


# ---- B: hero + slim strips ------------------------------------------------------------
def option_b(idx=0):
    im, d = frame()
    y0, H, RULE = 150, 930, 14
    HERO = 1300
    strip = (1920 - HERO - 4 * RULE) // 4
    m = MOODS[idx]
    hero = pic(m[2], HERO, H)
    im.paste(hero, (0, y0))
    im.paste(Image.new("RGB", (HERO, 560), 0), (0, y0 + H - 560), shade(HERO, 560))
    im.paste(Image.new("RGB", (520, H), 0), (0, y0), shade(520, H).rotate(0).transpose(Image.ROTATE_90).resize((520, H)) if False else Image.new("L", (520, H), 0))
    d.text((96, y0 + H - 330), "MOOD 1 OF 5", font=caps(30), fill=GOLD)
    d.text((92, y0 + H - 290), m[0], font=caps(150), fill=INK)
    d.text((98, y0 + H - 130), m[1], font=fell(40), fill=MUTED)
    x = 98
    x = key(d, x, y0 + H - 72, "ok", "Play full screen")
    x = key(d, x, y0 + H - 72, "star", "Sound and timer")
    speaker(d, HERO - 80, y0 + 34)
    x = HERO
    im.paste(weave, (x, y0), weave); x += RULE
    for i, (t, s, mm) in enumerate(MOODS):
        if i == idx: continue
        p = pic(mm, strip, H)
        p = Image.blend(p, Image.new("RGB", p.size, NIGHT), 0.35)
        im.paste(p, (x, y0)); im.paste(Image.new("RGB", (strip, 400), 0), (x, y0 + H - 400), shade(strip, 400))
        # vertical title, reading bottom to top
        tw = int(d.textlength(t, font=caps(52))) + 10
        timg = Image.new("RGBA", (tw, 64), (0, 0, 0, 0))
        ImageDraw.Draw(timg).text((0, 0), t, font=caps(52), fill=INK)
        timg = timg.rotate(90, expand=True)
        im.paste(timg, (x + (strip - timg.width) // 2, y0 + H - 40 - timg.height), timg)
        x += strip
        if x < 1900: im.paste(weave, (x, y0), weave); x += RULE
    return im


# ---- C: three wide panels, carousel ---------------------------------------------------
def option_c(idx=1, rule=None, RULE=14):
    im, d = frame()
    y0, H = 150, 930
    rule = rule or weave
    W = (1920 - 2 * RULE - 2 * 120) // 3  # three full panels plus a peek at each side
    x = 120 - W - RULE
    for i in range(idx - 2, idx + 3):
        if 0 <= i < len(MOODS):
            t, s, m = MOODS[i]
            p = pic(m, W, H)
            foc = (i == idx)
            if not foc: p = Image.blend(p, Image.new("RGB", p.size, NIGHT), 0.45)
            im.paste(p, (x, y0))
            im.paste(Image.new("RGB", (W, 420), 0), (x, y0), shade(W, 420, top=True, strength=200))
            d.text((x + 40, y0 + 40), f"{i+1:02d}", font=caps(34), fill=GOLD if foc else MUTED)
            d.text((x + 40, y0 + 80), t, font=caps(92), fill=GOLD if foc else INK)
            d.text((x + 44, y0 + 186), s, font=fell(34), fill=MUTED)
            if foc:
                d.rectangle((x, y0 + H - 6, x + W, y0 + H), fill=GOLD)
                im.paste(Image.new("RGB", (W, 200), 0), (x, y0 + H - 200), shade(W, 200, strength=180))
                xx = key(d, x + 40, y0 + H - 80, "ok", "Play")
                speaker(d, xx, y0 + H - 76)
                d.text((xx + 54, y0 + H - 60), "Sound on", font=uir(24), fill=MUTED, anchor="lm")
        x += W
        im.paste(rule, (x, y0), rule); x += RULE
    # scroll dots
    for i in range(len(MOODS)):
        cx = 960 - 2 * 26 + i * 26
        d.ellipse((cx - 6, 1052, cx + 6, 1064), fill=GOLD if i == idx else (70, 70, 56))
    return im


def label(im, title, sub):
    d = ImageDraw.Draw(im)
    d.rectangle((0, 0, 1920, 6), fill=GOLD)
    return im

if __name__ == "__main__":
  OUT = sys.argv[1]
  os.makedirs(OUT, exist_ok=True)
  option_a().save(os.path.join(OUT, "A-five-columns.png"))
  option_b().save(os.path.join(OUT, "B-hero-and-strips.png"))
  option_c().save(os.path.join(OUT, "C-three-panels.png"))
  # overview
  ov = Image.new("RGB", (1920, 1240), NIGHT); d = ImageDraw.Draw(ov)
  for k, (f, t) in enumerate([("A-five-columns.png", "A  Five columns, focused one widens"), ("B-hero-and-strips.png", "B  Big picture + slim strips"), ("C-three-panels.png", "C  Three wide panels that slide")]):
      im = Image.open(os.path.join(OUT, f)).resize((620, 349), Image.LANCZOS)
      x = 20 + k * 630
      ov.paste(im, (x, 120)); d.text((x, 490), t, font=ui(26), fill=INK)
  d.text((20, 40), "Ambiance room: three layouts (pictures are placeholders until your clips)", font=ui(34), fill=GOLD)
  ov = ov.crop((0, 0, 1920, 560)); ov.save(os.path.join(OUT, "00-overview.png"))
