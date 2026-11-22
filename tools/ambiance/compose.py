"""Composite the layers the way the TV does, for previews and the room tiles.

    python3 tools/ambiance/compose.py png_dir fire_sheet.jpg out_dir
"""
import sys, os
from PIL import Image

FIRE_AT = (600, 420)      # where the 720 x 540 fire sits on screen (must match MoodScene.xml)
LOGS_AT = (580, 830)
WIN = (960 - 420, 480 - 420)  # rain overlay origin


def hearth(png, sheet, k=5):
    bg = Image.open(os.path.join(png, "hearth-bg.png")).convert("RGBA")
    f = sheet.crop(((k % 8) * 240, (k // 8) * 180, (k % 8) * 240 + 240, (k // 8) * 180 + 180)).resize((720, 540), Image.BILINEAR)
    bg.paste(f, FIRE_AT)
    glow = Image.open(os.path.join(png, "hearth-glow.png")).resize((1920, 1080), Image.BILINEAR)
    bg.alpha_composite(glow)
    bg.alpha_composite(Image.open(os.path.join(png, "hearth-logs.png")), LOGS_AT)
    return bg.convert("RGB")


def rain(png):
    bg = Image.open(os.path.join(png, "rain-bg.png")).convert("RGBA")
    for n, dy in (("rain-far", 130), ("rain-near", 420)):
        st = Image.open(os.path.join(png, n + ".png"))
        layer = Image.new("RGBA", bg.size)
        layer.paste(st, (WIN[0], WIN[1] - dy))
        layer.paste(st, (WIN[0], WIN[1] - dy + 840))
        crop = Image.new("RGBA", bg.size)
        crop.paste(layer.crop((WIN[0], WIN[1], WIN[0] + 840, WIN[1] + 840)), WIN)
        bg.alpha_composite(crop)
    bg.alpha_composite(Image.open(os.path.join(png, "rain-window.png")), WIN)
    return bg.convert("RGB")


def night(png):
    return Image.open(os.path.join(png, "night-bg.png")).convert("RGB")


if __name__ == "__main__":
    png, sheet, out = sys.argv[1], Image.open(sys.argv[2]), sys.argv[3]
    os.makedirs(out, exist_ok=True)
    for name, img in (("hearth", hearth(png, sheet)), ("rain", rain(png)), ("night", night(png))):
        img.save(os.path.join(out, name + "-preview.jpg"), quality=88)
    print("ok")
