#!/usr/bin/env python3
"""Pre-build check for things bsc accepts but the Roku compiler rejects. Exit 1 on any hit.
Usage: python3 tools/precheck.py   (from the repo root)"""
import re, sys, glob, os
# names of BrightScript global functions/keywords that must not be used as variable or parameter names
BAD = set("""and as dim each else elseif end endfor endfunction endif endsub endwhile exit for function goto if in let mod next not or print rem return step stop sub then to while""".split())
bad_count = 0
def hit(f, n, msg):
    global bad_count; bad_count += 1; print(f"{f}:{n}: {msg}")
for f in glob.glob('source/**/*.brs', recursive=True) + glob.glob('components/**/*.brs', recursive=True):
    for n, line in enumerate(open(f, encoding='utf-8'), 1):
        code = line.split("'")[0] if '"' not in line else line
        m = re.match(r'\s*(function|sub)\s+\w+\s*\((.*?)\)', code, re.I)
        if m:
            for prm in [q.strip().split()[0].split('=')[0] for q in m.group(2).split(',') if q.strip()]:
                if prm.lower() in BAD: hit(f, n, f"parameter named '{prm}' is a BrightScript built-in or reserved word")
        a = re.match(r'\s*(\w+)\s*=[^=]', code)
        if a and a.group(1).lower() in BAD:
            hit(f, n, f"variable named '{a.group(1)}' is a BrightScript built-in or reserved word")
        for fe in re.findall(r'for\s+each\s+(\w+)\s+in', code, re.I):
            if fe.lower() in BAD: hit(f, n, f"loop variable '{fe}' is a built-in or reserved word")
# duplicate functions across the scripts each component includes (Roku rejects these)
for x in glob.glob('components/**/*.xml', recursive=True):
    txt = open(x, encoding='utf-8').read()
    uris = re.findall(r'<script[^>]*uri="pkg:/([^"]+)"', txt)
    seen = {}
    for u in uris:
        if not os.path.exists(u): hit(x, 0, f"script include missing: {u}"); continue
        for n, line in enumerate(open(u, encoding='utf-8'), 1):
            m = re.match(r'\s*(?:function|sub)\s+(\w+)', line, re.I)
            if m:
                k = m.group(1).lower()
                if k in seen: hit(x, 0, f"function {m.group(1)} defined in both {seen[k]} and {u}")
                seen[k] = u
if bad_count: print(f"\n{bad_count} problem(s). Fix before building."); sys.exit(1)
print("precheck: ok")
