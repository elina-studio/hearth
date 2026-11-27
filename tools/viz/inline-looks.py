#!/usr/bin/env python3
"""Puts the Hearth looks (tools/viz/looks-src/*.js, in name order) inside page.html.
They must live inside page.html: older NucBox renderers only update their own files, and page.html is one."""
import os, re, sys
here = os.path.dirname(os.path.abspath(__file__))
src = os.path.join(here, 'looks-src')
body = '\n'.join(open(os.path.join(src, f), encoding='utf-8').read().rstrip() for f in sorted(os.listdir(src)) if f.endswith('.js'))
if '</script' in body.lower():
    sys.exit('a look file contains </script, which would end the block early')
page = os.path.join(here, 'page.html')
html = open(page, encoding='utf-8').read()
pat = re.compile(r"<script>\n// Hearth's own visualizer looks.*?</script>", re.S)
if len(pat.findall(html)) != 1:
    sys.exit('could not find exactly one Hearth looks block in page.html')
html = pat.sub(lambda m: '<script>\n' + body + '\n</script>', html)
open(page, 'w', encoding='utf-8', newline='\n').write(html)
print('page.html now holds', body.count('HL.mk(') + body.count("flight('"), 'look definitions,', len(html), 'bytes')
