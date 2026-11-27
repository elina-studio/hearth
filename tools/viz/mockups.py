"""PNG mockups of the Visualizer screens, drawn from the same numbers as the SceneGraph code (1920x1080).
python3 tools/viz/mockups.py <out dir> <frame.png for the visualizer screen>"""
import json, sys, os
from PIL import Image, ImageDraw, ImageFont, ImageFilter
OUT = sys.argv[1]; FRAME = sys.argv[2]
R = os.path.dirname(os.path.abspath(__file__)) + "/../.."
F = lambda k, s: ImageFont.truetype(R + "/fonts/" + {"bold": "HearthSans-Bold.ttf", "caps": "HearthSans-Bold.ttf", "regular": "HearthText-Regular.ttf"}[k], s)
LOOKS = json.load(open(R + "/tools/viz/looks.json"))
C = lambda h: tuple(int(h[i:i+2], 16) for i in (0, 2, 4)) + ((int(h[6:8], 16),) if len(h) > 6 else (255,))
def ring(img, x, y, w, h, i):
    r = Image.open(R + "/images/w/focus-ring-v%d.9.png" % (i % 6 + 1)).convert("RGBA")
    # a 9-patch: draw it stretched (close enough for a mockup)
    img.alpha_composite(r.resize((w, h)), (x, y))
def star(img, x, y):
    s = Image.open(R + "/images/music/icons/star.png").convert("RGBA").resize((28, 28))
    col = Image.new("RGBA", s.size, C("E0B34AFF")); col.putalpha(s.getchannel("A")); img.alpha_composite(col, (x, y))

def picker(focus, stars, choice, name):
    img = Image.new("RGBA", (1920, 1080), C("0B0E09F2")); d = ImageDraw.Draw(img)
    d.text((132, 64), "VISUALIZER LOOK", font=F("caps", 26), fill=C("D9A066"))
    items = [{"n": "shuffle", "label": "Shuffle"}] + [{"n": str(l["n"]), "label": l["label"]} for l in LOOKS]
    it = items[focus]
    if it["n"] == "shuffle":
        title = "Shuffle"; sub = "A different look for every song, from your %d starred looks." % len(stars)
    else:
        title = it["label"]; sub = ("Starred" if it["n"] in stars else "Not starred") + ("  ·  In use for every song" if it["n"] == choice else "")
    d.text((132, 104), title, font=F("bold", 52), fill=C("EDE6CA"))
    d.text((132, 184), sub, font=F("regular", 28), fill=C("B5AF8C"))
    tw, th, gx, gy, cols = 186, 105, 24, 76, 8
    for i, t in enumerate(items):
        x = 132 + (i % cols) * (tw + gx); y = 262 + (i // cols) * (th + gy)
        if i == focus: ring(img, x - 18, y - 18, tw + 36, th + 36, i)
        d.rectangle([x, y, x + tw - 1, y + th - 1], fill=C("1D2418"))
        if t["n"] == "shuffle":
            ic = Image.open(R + "/images/music/icons/shuffle.png").convert("RGBA").resize((56, 56))
            col = Image.new("RGBA", ic.size, C("E0B34A")); col.putalpha(ic.getchannel("A")); img.alpha_composite(col, (x + (tw - 56) // 2, y + (th - 56) // 2))
        else:
            img.paste(Image.open(R + "/images/music/viz/%s.jpg" % t["n"]).resize((tw, th)), (x, y))
        if t["n"] in stars:
            d.rectangle([x + tw - 40, y + 6, x + tw - 7, y + 39], fill=C("0B0E09B3")); star(img, x + tw - 37, y + 9)
        if t["n"] == choice: d.rectangle([x, y + th - 6, x + tw - 1, y + th - 1], fill=C("E0B34A"))
        f = F("regular", 22); lab = t["label"]
        while d.textlength(lab, font=f) > tw and len(lab) > 3: lab = lab[:-2].rstrip() + "…" if not lab.endswith("…") else lab[:-2] + "…"
        d.text((x + tw / 2, y + th + 24), lab, font=f, fill=C("EDE6CA" if i == focus else "B5AF8C"), anchor="ma")
    d.text((960, 992), "OK uses this look  ·  Play/Pause stars it  ·  Back closes", font=F("regular", 24), fill=C("B5AF8C"), anchor="ma")
    img.convert("RGB").save(OUT + "/" + name)

def viz(name):
    img = Image.open(FRAME).convert("RGBA").resize((1920, 1080)); d = ImageDraw.Draw(img)
    # look tag (top left) and the now-playing strip, as they show for a few seconds after a key press
    f = F("caps", 30); w = d.textlength("ANGEL FLIGHT", font=f)
    d.rectangle([80, 50, 80 + w + 48, 114], fill=C("0B0E09B3")); d.text((104, 62), "ANGEL FLIGHT", font=f, fill=C("EDE6CA"))
    d.rectangle([0, 860, 1920, 1080], fill=C("0B0E09D9")); d.rectangle([96, 890, 246, 1040], fill=C("5A4128"))
    d.text((280, 898), "VISUALIZER  ·  LIVE  ·  NOW PLAYING", font=F("caps", 26), fill=C("D9A066"))
    d.text((280, 936), "Song title", font=F("bold", 40), fill=C("EDE6CA"))
    d.text((280, 990), "Artist  ·  Album", font=F("regular", 26), fill=C("B5AF8C"))
    hint = ["Play pauses  ·  Rewind and Fast forward change song", "Up shows or hides lyrics  ·  Back closes", "Left and Right change the look  ·  OK all looks and options"]
    hf = F("regular", 22); y = 912
    for line in hint:
        # the Label wraps at 604 px, right aligned
        words = line.split(" "); cur = ""
        for wd in words:
            t = (cur + " " + wd).strip()
            if d.textlength(t, font=hf) > 604: d.text((1824, y), cur, font=hf, fill=C("B5AF8C"), anchor="ra"); y += 26; cur = wd
            else: cur = t
        d.text((1824, y), cur, font=hf, fill=C("B5AF8C"), anchor="ra"); y += 26
    img.convert("RGB").save(OUT + "/" + name)

def fallback(name):
    img = Image.open(FRAME).convert("RGBA").resize((1920, 1080)).filter(ImageFilter.GaussianBlur(30))
    img = Image.blend(Image.new("RGBA", img.size, C("0B0E09")), img, 0.35); d = ImageDraw.Draw(img)
    d.rectangle([0, 0, 1920, 1080], fill=None)
    f = F("regular", 32)
    lines = ["No visualizer for this song: the NucBox renderer is off and there's no", "ready-made loop for this look yet.", "The music carries on, and the next song tries again."]
    y = 420
    for l in lines: d.text((960, y), l, font=f, fill=C("B5AF8C"), anchor="ma"); y += 42
    img.convert("RGB").save(OUT + "/" + name)

stars = {"57", "60", "75", "98", "35"}
picker(14, stars, "shuffle", "viz-picker.png")
picker(0, stars, "shuffle", "viz-picker-shuffle.png")
viz("viz-playing.png")
fallback("viz-unavailable.png")
