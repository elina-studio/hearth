"""Mock of a full-screen mood with its HUD (matches MoodScreen.xml).  python3 mock_mood.py bg.jpg out.png [dim]"""
import sys
from PIL import Image, ImageDraw, ImageFont
bg = Image.open(sys.argv[1]).convert("RGB").resize((1920, 1080))
dim = float(sys.argv[3]) if len(sys.argv) > 3 else 0
im = Image.blend(bg, Image.new("RGB", bg.size, 0), dim)
shade = Image.new("L", (1, 300)); [shade.putpixel((0, k), int(220 * (k / 299) ** 1.3)) for k in range(300)]
im.paste(Image.new("RGB", (1920, 300), 0), (0, 780), shade.resize((1920, 300)))
d = ImageDraw.Draw(im)
caps = ImageFont.truetype("fonts/BarlowCondensed-Bold.ttf", 64)
bold = ImageFont.truetype("fonts/AtkinsonHyperlegible-Bold.ttf", 28)
reg = ImageFont.truetype("fonts/AtkinsonHyperlegible-Regular.ttf", 24)
big = ImageFont.truetype("fonts/AtkinsonHyperlegible-Bold.ttf", 40)
d.text((96, 900), "HEARTH", font=caps, fill=(237, 230, 202))
st = "Sound on   ·   Stops at 11:42" + (f"   ·   Dimmed {int(dim*100)}%" if dim else "")
d.text((96, 975), st, font=bold, fill=(224, 179, 74))
hint = "OK sound   ·   Left/Right mood   ·   Up/Down dim   ·   * options   ·   Back leaves"
d.text((1824 - d.textlength(hint, font=reg), 980), hint, font=reg, fill=(181, 175, 140))
d.text((1824 - d.textlength("9:42", font=big), 905), "9:42", font=big, fill=(237, 230, 202))
im.save(sys.argv[2])
