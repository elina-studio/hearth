"""Layout C with four divider options.  python3 mock_dividers.py png_dir out_dir"""
import sys, os
sys.path.insert(0, os.path.dirname(__file__))
from PIL import Image, ImageDraw
import mock_layouts as L
src, out = sys.argv[1:3]
opts = [("ribbon", "1  Woven ribbon"), ("knots", "2  Double line with knots"), ("vine", "3  Gold vine"), ("glow", "4  Single glowing line")]
ov = Image.new("RGB", (1920, 1080), L.NIGHT); d = ImageDraw.Draw(ov)
d.text((40, 30), "Ambiance C: divider options", font=L.ui(34), fill=L.GOLD)
for k, (name, title) in enumerate(opts):
    rule = Image.open(os.path.join(src, name + ".png"))
    im = L.option_c(rule=rule, RULE=24)
    im.save(os.path.join(out, f"C-divider-{k+1}-{name}.png"))
    # close-up: the seam between panels at 1:1
    x0 = 120 + (1920 - 2 * 24 - 240) // 3 - 90
    crop = im.crop((x0, 380, x0 + 200, 980))
    ov.paste(crop, (60 + k * 470, 120)); d.text((60 + k * 470, 740), title, font=L.ui(28), fill=L.INK)
    ov.paste(im.resize((420, 236)), (60 + k * 470, 800))
ov.save(os.path.join(out, "C-dividers-overview.png"))
