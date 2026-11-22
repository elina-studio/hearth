# Render icons.py to white 48x48 PNGs in images/music/icons/ (tinted on the TV with blendColor).
# python3 tools/music/icons_png.py && node tools/music/icons_png.js
import os, json
from icons import ICONS, svg
here = os.path.dirname(os.path.abspath(__file__))
pages = {n: f'<html><body style="margin:0;background:transparent">{svg(n,48,"#ffffff",2)}</body></html>' for n in ICONS}
json.dump(pages, open(os.path.join(here, 'icons.json'), 'w'))
