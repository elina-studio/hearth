# Give Hearth's small-text and Fell fonts the Greek and Cyrillic letters they lack, borrowed from
# HearthSans (Ysabeau), so names like "Кино" don't draw as boxes. All three fonts are SIL OFL 1.1;
# the results are renamed (HearthText, HearthFell) as the licence asks for modified versions.
#   python3 tools/fonts/add_cyrillic.py   (writes fonts/HearthText-Regular.ttf, fonts/HearthFell-Italic.ttf)
import os
from fontTools.ttLib import TTFont
from fontTools.pens.recordingPen import DecomposingRecordingPen
from fontTools.pens.transformPen import TransformPen
from fontTools.pens.ttGlyphPen import TTGlyphPen

here = os.path.dirname(os.path.abspath(__file__))
root = os.path.join(here, '..', '..')
DONOR = os.path.join(root, 'fonts', 'HearthSans-Bold.ttf')
RANGES = [(0x370, 0x3FF), (0x400, 0x52F), (0x1F00, 0x1FFF)]

def merge(src, out, family, style, slant=0.0):
    t = TTFont(src)
    d = TTFont(DONOR)
    dset = d.getGlyphSet()
    dcm = d.getBestCmap()
    tcm = t.getBestCmap()
    k = t['head'].unitsPerEm / d['head'].unitsPerEm
    order = t.getGlyphOrder()
    added = {}
    for cp, gname in sorted(dcm.items()):
        if cp in tcm or not any(a <= cp <= b for a, b in RANGES):
            continue
        rec = DecomposingRecordingPen(dset)
        dset[gname].draw(rec)
        pen = TTGlyphPen(None)
        rec.replay(TransformPen(pen, (k, 0, k * slant, k, 0, 0)))  # slant leans the letters for the italic
        g = pen.glyph()
        name = 'uni%04X' % cp if cp <= 0xFFFF else 'u%05X' % cp
        if name in t['glyf'].glyphs or name in order:
            name += '.hs'
        t['glyf'][name] = g
        g.recalcBounds(t['glyf'])
        adv = round(d['hmtx'][gname][0] * k)
        t['hmtx'][name] = (adv, getattr(g, 'xMin', 0))
        if name not in order: order.append(name)
        added[cp] = name
    t.setGlyphOrder(order)
    t['glyf'].glyphOrder = order
    for sub in t['cmap'].tables:
        if sub.isUnicode():
            for cp, name in added.items():
                if sub.format == 4 and cp > 0xFFFF:
                    continue
                sub.cmap[cp] = name
    if 'post' in t and t['post'].formatType == 2.0:
        t['post'].extraNames = []
        t['post'].mapping = {}
    for rec in t['name'].names:
        if rec.nameID in (1, 16):
            rec.string = family
        elif rec.nameID in (4,):
            rec.string = family + ' ' + style
        elif rec.nameID in (6,):
            rec.string = family.replace(' ', '') + '-' + style.replace(' ', '')
    t['maxp'].numGlyphs = len(order)
    t.save(out)
    print(os.path.basename(out), 'added', len(added), 'glyphs')

merge(os.path.join(here, 'src', 'AtkinsonHyperlegible-Regular.ttf'), os.path.join(root, 'fonts', 'HearthText-Regular.ttf'), 'HearthText', 'Regular')
merge(os.path.join(here, 'src', 'IMFellEnglish-Italic.ttf'), os.path.join(root, 'fonts', 'HearthFell-Italic.ttf'), 'HearthFell', 'Italic', slant=0.2)
