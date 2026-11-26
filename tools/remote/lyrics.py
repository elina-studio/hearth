"""Lyrics for Hearth Music. Standard library only.

Order: a .lrc / .txt file next to the song (path from Plex), then LRCLIB (free, no key). Only artist,
title, album and length are ever sent to LRCLIB. Results (and misses, for a week) are cached in DATA_DIR.
"""
import hashlib
import json
import os
import re
import time
import urllib.parse
import urllib.request

DATA_DIR = os.environ.get("DATA_DIR", "/data")
MUSIC_ROOT = os.environ.get("MUSIC_ROOT", "/volume1")  # sidecar files must live under this folder
UA = "Hearth/1 (https://github.com/elina-studio/hearth)"
MISS_DAYS = 7

STAMP = re.compile(r"\[(\d{1,3}):(\d{2})(?:[.:](\d{1,3}))?\]")


def parse_lrc(text):
    """-> (times, lines) sorted by time. Plain text without stamps gives ([], [])."""
    out = []
    offset = 0.0
    for raw in text.splitlines():
        m = re.match(r"\s*\[offset:\s*(-?\d+)\]", raw, re.I)
        if m:
            offset = int(m.group(1)) / 1000.0
            continue
        stamps = STAMP.findall(raw)
        if not stamps:
            continue
        line = STAMP.sub("", raw).strip()
        for mm, ss, frac in stamps:
            f = float("0." + frac) if frac else 0.0
            out.append((int(mm) * 60 + int(ss) + f, line))
    out.sort(key=lambda x: x[0])
    times = [round(max(0.0, t + offset), 2) for t, _ in out]
    lines = [l for _, l in out]
    return times, lines


def strip_stamps(text):
    return "\n".join(STAMP.sub("", l).strip() for l in text.splitlines() if not re.match(r"\s*\[[a-z]+:", l, re.I)).strip()


def _cache_path(artist, title, album, duration, file):
    key = "|".join([artist.lower(), title.lower(), album.lower(), str(int(duration or 0) // 2), file])
    return os.path.join(DATA_DIR, "lyrics", hashlib.sha1(key.encode()).hexdigest() + ".json")


def _sidecar(file):
    if not file:
        return None
    root = os.path.realpath(MUSIC_ROOT)
    base = os.path.realpath(os.path.splitext(file)[0])
    if not (base == root or base.startswith(root + os.sep)):
        return None
    for ext in (".lrc", ".LRC", ".txt"):
        p = base + ext
        if os.path.isfile(p):
            return p
    return None


def _lrclib(artist, title, album, duration):
    def get(url):
        req = urllib.request.Request(url, headers={"User-Agent": UA})
        with urllib.request.urlopen(req, timeout=8) as r:
            return json.loads(r.read().decode("utf-8", "replace"))

    q = {"artist_name": artist, "track_name": title}
    if album:
        q["album_name"] = album
    if duration:
        q["duration"] = str(int(duration))
    try:
        return get("https://lrclib.net/api/get?" + urllib.parse.urlencode(q))
    except Exception:
        pass
    try:  # looser: search, take the closest length
        hits = get("https://lrclib.net/api/search?" + urllib.parse.urlencode({"artist_name": artist, "track_name": title}))
        best = None
        for h in hits or []:
            if duration and abs((h.get("duration") or 0) - duration) > 4:
                continue
            if h.get("syncedLyrics") or h.get("plainLyrics"):
                if best is None or (h.get("syncedLyrics") and not best.get("syncedLyrics")):
                    best = h
        return best
    except Exception:
        return False  # couldn't ask at all (offline, timeout): not the same as "no lyrics exist"


def find(artist, title, album="", duration=0, file=""):
    artist, title, album = artist.strip(), title.strip(), album.strip()
    if not title:
        return {"source": "none", "times": [], "lines": [], "plain": ""}
    cp = _cache_path(artist, title, album, duration, file)
    try:
        with open(cp) as fh:
            hit = json.load(fh)
        if hit.get("source") != "none" or time.time() - hit.get("at", 0) < MISS_DAYS * 86400:
            return hit
    except Exception:
        pass
    res = {"source": "none", "times": [], "lines": [], "plain": "", "at": time.time()}
    side = _sidecar(file)
    text = ""
    if side:
        try:
            with open(side, "rb") as fh:
                text = fh.read().decode("utf-8", "replace")
            res["source"] = "file"
        except Exception:
            text = ""
    if not text:
        h = _lrclib(artist, title, album, duration)
        if h is False:
            # don't remember a network failure as "no lyrics" for a week: ask again next time
            return res
        if h:
            text = h.get("syncedLyrics") or h.get("plainLyrics") or ""
            if text:
                res["source"] = "lrclib"
    if text:
        times, lines = parse_lrc(text)
        if len(times) >= 3:
            res["times"], res["lines"] = times, lines
        else:
            res["plain"] = strip_stamps(text)
        if not res["times"] and not res["plain"]:
            res["source"] = "none"
    try:
        os.makedirs(os.path.dirname(cp), exist_ok=True)
        with open(cp, "w") as fh:
            json.dump(res, fh)
    except Exception:
        pass
    return res
