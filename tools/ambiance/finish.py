"""Turn rendered layers into the files the channel ships.  python3 finish.py tmp images/amb sounds"""
import sys, os, subprocess, random
from PIL import Image, ImageDraw, ImageFilter
sys.path.insert(0, os.path.dirname(__file__))
import compose

tmp, img, snd = sys.argv[1:4]
png = os.path.join(tmp, "png")
os.makedirs(img, exist_ok=True); os.makedirs(snd, exist_ok=True)


# The TV's UI runs at 1280 x 720, so full-screen layers ship at 2/3 size; posters keep their 1920-space sizes and Roku scales.
def jpg(name, out, q=86):
    Image.open(os.path.join(png, name)).convert("RGB").resize((1280, 720), Image.LANCZOS).save(os.path.join(img, out), quality=q, optimize=True, progressive=False)


def keep(name, out, size=None):
    im = Image.open(os.path.join(png, name))
    if size: im = im.resize(size, Image.LANCZOS)
    im.save(os.path.join(img, out), optimize=True)


jpg("hearth-bg.png", "hearth-bg.jpg")
jpg("rain-bg.png", "rain-bg.jpg")
jpg("night-bg.png", "night-bg.jpg")
keep("hearth-logs.png", "hearth-logs.png", (507, 113))
keep("hearth-glow.png", "hearth-glow.png", (480, 270))
keep("rain-window.png", "rain-window.png", (560, 560))
keep("rain-far.png", "rain-far.png", (560, 560))
keep("rain-near.png", "rain-near.png", (560, 560))
keep("vine.png", "divider.png")  # the divider the person picks (see mockups/ambiance)
Image.open(os.path.join(tmp, "fire.jpg")).save(os.path.join(img, "fire.jpg"), quality=86)

# room tiles, 300 x 420, cut from the composed scenes
sheet = Image.open(os.path.join(tmp, "fire.jpg"))
TW, TH = 300, 420
def tile(im, cx, cy, scale, out):
    w, h = TW * scale, TH * scale
    im.crop((int(cx - w / 2), int(cy - h / 2), int(cx + w / 2), int(cy + h / 2))).resize((TW, TH), Image.LANCZOS).save(os.path.join(img, out), quality=88)
tile(compose.hearth(png, sheet), 960, 640, 1.6, "tile-hearth.jpg")
tile(compose.rain(png), 960, 560, 1.75, "tile-rain.jpg")
tile(compose.night(png), 640, 640, 1.6, "tile-fireflies.jpg")
# full-height column pictures, 760 x 930 (placeholders until the footage stills replace them)
CW, CH = 760, 930
def col(im, cx, cy, scale, out):
    w, h = CW * scale, CH * scale
    x0 = max(0, min(1920 - w, cx - w / 2)); y0 = max(0, min(1080 - h, cy - h / 2))
    im.crop((int(x0), int(y0), int(x0 + w), int(y0 + h))).resize((CW, CH), Image.LANCZOS).save(os.path.join(img, out), quality=84)
col(compose.hearth(png, sheet), 960, 600, 1.12, "col-hearth.jpg")
col(compose.rain(png), 960, 520, 1.12, "col-rain.jpg")
col(compose.night(png), 700, 560, 1.15, "col-fireflies.jpg")

# lights out: near-black, a low ember glow and a sliver of moon
R = random.Random(3)
im = Image.new("RGB", (TW, TH), (5, 7, 5))
g = Image.new("L", (TW, TH), 0); d = ImageDraw.Draw(g)
d.ellipse((60, 330, 240, 430), fill=110)
g = g.filter(ImageFilter.GaussianBlur(30))
im = Image.composite(Image.new("RGB", (TW, TH), (120, 46, 12)), im, g)
d = ImageDraw.Draw(im)
for k in range(14):
    x, y = R.uniform(90, 210), R.uniform(372, 404); r = R.uniform(1.5, 3.5)
    d.ellipse((x - r, y - r, x + r, y + r), fill=R.choice([(255, 150, 60), (230, 90, 30), (255, 190, 90)]))
d.ellipse((205, 70, 245, 110), fill=(205, 204, 180)); d.ellipse((216, 64, 256, 104), fill=(5, 7, 5))
im.save(os.path.join(img, "tile-lightsout.jpg"), quality=88)
im.resize((CW, int(TH * CW / TW)), Image.LANCZOS).crop((0, 0, CW, CH)).save(os.path.join(img, "col-lightsout.jpg"), quality=84)
# the window (photos): a dim round frame
im = Image.new("RGB", (TW, TH), (14, 20, 18)); d = ImageDraw.Draw(im)
d.ellipse((40, 90, 260, 310), outline=(90, 62, 34), width=14)
d.ellipse((54, 104, 246, 296), fill=(38, 52, 46))
d.ellipse((150, 170, 230, 250), fill=(70, 82, 64))
d.polygon([(54, 260), (130, 190), (200, 240), (246, 220), (246, 296), (54, 296)], fill=(24, 36, 28))
im.save(os.path.join(img, "tile-window.jpg"), quality=88)
im.resize((CW, int(TH * CW / TW)), Image.LANCZOS).crop((0, 0, CW, CH)).save(os.path.join(img, "col-window.jpg"), quality=84)

for name in ("fire", "rain", "night"):
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", os.path.join(tmp, name + ".wav"), "-ac", "1", "-b:a", "64k", os.path.join(snd, name + ".mp3")], check=True)
    os.replace(os.path.join(tmp, name + "-short.wav"), os.path.join(snd, name + "-loop.wav"))
print("done")
