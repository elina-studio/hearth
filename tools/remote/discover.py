"""Hearth Music "Discover": artists you love and artists you might like, from Last.fm. Standard library only.

Source: the Last.fm account paired on the phone (lastfm.json holds the user name). Read calls only need the API key.
  loved   = your top artists, 12 months (60%) mixed with all time (40%)
  recs    = Last.fm "similar artists" of your top 25, scored by (how much you play the source) x (how close the match)
            minus artists you already play a lot (your top 300 all time) and anyone you pressed "Not for me" on
Built once a day in the background and kept in DATA_DIR/discover.json, so the TV opens instantly.
  GET  /api/discover                 -> {loved, recs, built, user}   (?refresh=1 rebuilds now)
  GET  /api/discover/albums?artist=  -> that artist's top albums (Last.fm), cached
  POST /api/discover/hide {name}     -> never recommend that artist again
"""
import json
import os
import threading
import time

import lastfm

FILE = os.path.join(lastfm.DATA_DIR, "discover.json")
lock = threading.RLock()
BUILD_EVERY = 24 * 3600
_building = False


def _load():
    try:
        with open(FILE) as fh:
            return json.load(fh)
    except Exception:
        return {}


def _save(d):
    os.makedirs(lastfm.DATA_DIR, exist_ok=True)
    tmp = FILE + ".tmp"
    with open(tmp, "w") as fh:
        json.dump(d, fh)
    os.replace(tmp, FILE)


def _get(method, **kw):
    p = {"method": method}
    p.update(kw)
    for _ in range(3):
        r = lastfm._call(p, post=False)
        if r.get("error") in lastfm.RETRY:
            time.sleep(2)
            continue
        return r
    return r


def _top(user, period, limit):
    r = _get("user.getTopArtists", user=user, period=period, limit=limit)
    out = []
    for a in (r.get("topartists", {}).get("artist") or []):
        try:
            out.append({"name": a["name"], "mbid": a.get("mbid", ""), "plays": int(a.get("playcount", 0))})
        except (KeyError, ValueError):
            pass
    return out


def build():
    global _building
    with lock:
        if _building:
            return
        _building = True
    try:
        user = lastfm._load().get("user", "")
        if not user or not lastfm.configured():
            return
        recent = _top(user, "12month", 100)
        allt = _top(user, "overall", 300)
        if not recent and not allt:
            return
        score = {}
        info = {}
        for lst, w in ((recent, 0.6), (allt[:100], 0.4)):
            top = max([a["plays"] for a in lst] or [1])
            for a in lst:
                score[a["name"]] = score.get(a["name"], 0) + w * a["plays"] / top
                info.setdefault(a["name"], a)
        loved = sorted(info.values(), key=lambda a: -score[a["name"]])[:40]
        for a in loved:
            a["score"] = round(score[a["name"]], 3)
        known = {a["name"].lower() for a in allt}
        hidden = {h.lower() for h in _load().get("hidden", [])}
        rec = {}
        for src in loved[:25]:
            r = _get("artist.getSimilar", artist=src["name"], limit=30, autocorrect=1)
            for s in (r.get("similarartists", {}).get("artist") or []):
                n = s.get("name", "")
                if not n or n.lower() in known or n.lower() in hidden:
                    continue
                try:
                    m = float(s.get("match", 0))
                except ValueError:
                    continue
                e = rec.setdefault(n, {"name": n, "mbid": s.get("mbid", ""), "score": 0.0, "because": src["name"], "best": 0.0})
                v = score[src["name"]] * m
                e["score"] += v
                if v > e["best"]:
                    e["best"], e["because"] = v, src["name"]
            time.sleep(0.3)
        recs = sorted(rec.values(), key=lambda e: -e["score"])[:80]
        for e in recs:
            e["score"] = round(e["score"], 3)
            e.pop("best", None)
        d = _load()
        d.update({"loved": loved, "recs": recs, "built": int(time.time()), "user": user})
        _save(d)
        print("[discover] built: %d loved, %d recommended" % (len(loved), len(recs)), flush=True)
    finally:
        _building = False


def get(refresh=False):
    d = _load()
    if (refresh or not d.get("built")) and not _building:
        threading.Thread(target=build, daemon=True).start()
    hidden = {h.lower() for h in d.get("hidden", [])}
    return {"loved": d.get("loved", []), "recs": [e for e in d.get("recs", []) if e["name"].lower() not in hidden],
            "built": d.get("built", 0), "user": d.get("user", ""), "building": _building}


def albums(artist):
    d = _load()
    c = d.setdefault("albums", {})
    hit = c.get(artist.lower())
    if hit and time.time() - hit["t"] < 7 * 86400:
        return {"albums": hit["a"]}
    r = _get("artist.getTopAlbums", artist=artist, limit=8, autocorrect=1)
    out = []
    for a in (r.get("topalbums", {}).get("album") or []):
        n = a.get("name", "")
        if n and n != "(null)":
            out.append({"name": n, "plays": a.get("playcount", "")})
    if out:
        with lock:
            d = _load()
            d.setdefault("albums", {})[artist.lower()] = {"t": time.time(), "a": out}
            _save(d)
    return {"albums": out}


def hide(name):
    with lock:
        d = _load()
        h = d.setdefault("hidden", [])
        if name and name.lower() not in [x.lower() for x in h]:
            h.append(name)
        _save(d)
    return {"ok": True}


def worker():
    while True:
        d = _load()
        if lastfm._load().get("user") and time.time() - d.get("built", 0) > BUILD_EVERY:
            try:
                build()
            except Exception as e:
                print("[discover] build failed:", e, flush=True)
        time.sleep(1800)
