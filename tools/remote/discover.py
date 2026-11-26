"""Hearth Music "Discover": artists you love and artists you might like, from Last.fm. Standard library only.

Source: the Last.fm account paired on the phone (lastfm.json holds the user name). Read calls only need the API key.
  loved   = your top artists, 12 months (60%) mixed with all time (40%)
  recs    = Last.fm "similar artists" of your top 25, scored by (how much you play the source) x (how close the match)
            minus artists you already play a lot (your top 300 all time) and anyone you pressed "Not for me" on
Built once a day in the background and kept in DATA_DIR/discover.json, so the TV opens instantly.
  GET  /api/discover                 -> {loved, recs, built, user, fresh, plays}   (?refresh=1 rebuilds now)
  GET  /api/discover/albums?artist=  -> that artist's top albums (Last.fm), cached
  POST /api/discover/hide {name}     -> never recommend that artist again
"""
import datetime
import json
import os
import threading
import time
import urllib.parse
import urllib.request

import urllib.error

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
        _build()
    except Exception as e:
        import traceback
        traceback.print_exc()
        _fail("%s: %s" % (type(e).__name__, e))
    finally:
        _building = False


def _build():
    if True:
        user = lastfm._load().get("user", "")
        if not user or not lastfm.configured():
            _fail("no Last.fm user paired yet" if not user else "no Last.fm key on the helper")
            return
        recent = _top(user, "12month", 100)
        allt = _top(user, "overall", 300)
        if not recent and not allt:
            r = _get("user.getTopArtists", user=user, period="overall", limit=1)
            _fail("Last.fm gave no top artists for %s: %s" % (user, r.get("message", "empty answer")))
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
        with lock:
            d = _load()
            d.pop("error", None)
            plays = {a["name"].lower(): a["plays"] for a in allt}
            d.update({"loved": loved, "recs": recs, "plays": plays, "built": int(time.time()), "user": user})
            _save(d)
        print("[discover] built: %d loved, %d recommended" % (len(loved), len(recs)), flush=True)
        # then new releases: the artists you play (top 300 all time) and the top 40 recommended, checked on MusicBrainz
        who = [(a["name"], a.get("mbid", ""), "yours") for a in allt] + [(e["name"], e.get("mbid", ""), "recommended") for e in recs[:40]]
        with lock:
            d = _load()
            d["freshTried"] = int(time.time())
            _save(d)
        fresh = scan_fresh(who)
        with lock:
            d = _load()
            d.update({"fresh": fresh, "freshBuilt": int(time.time())})
            _save(d)
        print("[discover] new releases: %d from %d artists" % (len(fresh), len(who)), flush=True)


MB = "https://musicbrainz.org/ws/2/release-group/"
SKIP = {"compilation", "live", "remix", "dj-mix", "mixtape/street", "demo", "soundtrack", "spokenword", "interview", "audiobook"}


def _mb(query):
    url = MB + "?" + urllib.parse.urlencode({"query": query, "fmt": "json", "limit": 25})
    req = urllib.request.Request(url, headers={"User-Agent": lastfm.UA, "Accept": "application/json"})
    for attempt in range(3):
        try:
            with urllib.request.urlopen(req, timeout=15) as r:
                return json.loads(r.read().decode("utf-8", "replace"))
        except urllib.error.HTTPError as e:
            if e.code in (429, 503):
                time.sleep(3 + attempt * 3)
                continue
            return {}
        except Exception:
            time.sleep(2)
    return {}


def _day(s):
    """'2026-11-20' -> date; '2026-11' -> the 1st of that month; a bare year is too vague to call new."""
    try:
        if len(s) == 10:
            return datetime.date.fromisoformat(s)
        if len(s) == 7:
            return datetime.date.fromisoformat(s + "-01")
    except ValueError:
        pass
    return None


def scan_fresh(who, back=60, ahead=180):
    """Albums and EPs released in the last `back` days or due in the next `ahead`, for each (name, mbid, why).
    MusicBrainz allows about one request a second, so this takes a few minutes for ~340 artists."""
    today = datetime.date.today()
    lo, hi = today - datetime.timedelta(days=back), today + datetime.timedelta(days=ahead)
    rng = "firstreleasedate:[%s TO %s]" % (lo.isoformat(), hi.isoformat())
    out, seen = [], set()
    for name, mbid, why in who:
        if mbid:
            q = "arid:%s AND %s AND (primarytype:album OR primarytype:ep)" % (mbid, rng)
        else:
            q = 'artist:"%s" AND %s AND (primarytype:album OR primarytype:ep)' % (name.replace('"', ""), rng)
        r = _mb(q)
        time.sleep(1.1)
        for g in r.get("release-groups") or []:
            if {t.lower() for t in g.get("secondary-types") or []} & SKIP:
                continue
            day = _day(g.get("first-release-date", ""))
            if not day or day < lo or day > hi:
                continue
            credit = "".join(c.get("name", "") + c.get("joinphrase", "") for c in g.get("artist-credit") or []) or name
            if not mbid and credit.lower() != name.lower():
                continue   # a name search can match someone else
            key = (credit.lower(), g.get("title", "").lower())
            if key in seen:
                continue
            seen.add(key)
            out.append({"title": g.get("title", ""), "artist": credit, "date": day.isoformat(),
                        "kind": (g.get("primary-type") or "Album").lower(), "rgid": g.get("id", ""), "why": why})
    out.sort(key=lambda x: x["date"], reverse=True)
    return out


def _fail(msg):
    print("[discover] build failed:", msg, flush=True)
    with lock:
        d = _load()
        d["error"] = msg
        d["tried"] = int(time.time())
        _save(d)


def get(refresh=False):
    d = _load()
    stale = not d.get("freshBuilt") and time.time() - d.get("freshTried", 0) > 3600
    retry = not d.get("built") and time.time() - d.get("tried", 0) > 120
    started = False
    if (refresh or retry or (d.get("built") and stale)) and not _building:
        threading.Thread(target=build, daemon=True).start()
        started = True
    hidden = {h.lower() for h in d.get("hidden", [])}
    return {"loved": d.get("loved", []), "recs": [e for e in d.get("recs", []) if e["name"].lower() not in hidden],
            "built": d.get("built", 0), "user": d.get("user", ""), "building": _building or started,
            "error": "" if started else d.get("error", ""),
            "fresh": d.get("fresh", []), "freshBuilt": d.get("freshBuilt", 0), "plays": d.get("plays", {})}


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
