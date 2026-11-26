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


def _get(method, tries=3, signed=False, **kw):
    """A read-only Last.fm call, retried: Last.fm often answers 8 "Operation failed" and then works a moment later."""
    p = {"method": method}
    p.update(kw)
    if signed:
        p["sk"] = lastfm._load().get("session", "")
    r = {}
    for attempt in range(tries):
        r = lastfm._call(p, post=False, sign=signed, timeout=30)
        if r.get("error") in lastfm.RETRY or r.get("error") == 8:
            time.sleep(2 + attempt * 3)
            continue
        return r
    return r


def _artists(r):
    """The artist list out of any of the Last.fm answers used here."""
    for k in ("topartists", "artists", "weeklyartistchart"):
        if isinstance(r.get(k), dict):
            a = r[k].get("artist") or []
            return a if isinstance(a, list) else [a]
    return []


def _paged(limit, method, **kw):
    out, page = [], 1
    while len(out) < limit:
        r = _get(method, page=page, limit=50, **kw)
        got = _artists(r)
        if not got:
            if page == 1:
                return [], r.get("message", "empty answer")
            break
        for a in got:
            try:
                out.append({"name": a["name"], "mbid": a.get("mbid", ""), "plays": int(a.get("playcount", 0))})
            except (KeyError, ValueError, TypeError):
                pass
        if len(got) < 50:
            break
        page += 1
        time.sleep(0.3)
    return out[:limit], ""


def _plex_top(limit):
    """Artists by how many times their tracks were played in Plex (every music library), most played first."""
    try:
        import web
        k = web.keys()
        base = (k.get("plexServer") or "http://192.168.254.41:32400").rstrip("/")
        tok = k.get("plexServerToken") or k.get("plexToken") or ""
        if not tok:
            print("[discover] no Plex token saved on the helper", flush=True)
            return []

        def px(path):
            sep = "&" if "?" in path else "?"
            req = urllib.request.Request(base + path + sep + "X-Plex-Token=" + urllib.parse.quote(tok),
                                         headers={"Accept": "application/json"})
            with urllib.request.urlopen(req, timeout=60) as r:
                return json.loads(r.read().decode("utf-8", "replace")).get("MediaContainer", {})

        plays = {}
        for sec in px("/library/sections").get("Directory", []):
            if sec.get("type") != "artist":
                continue
            mc = px("/library/sections/%s/all?type=10&sort=viewCount:desc&X-Plex-Container-Start=0&X-Plex-Container-Size=8000" % sec["key"])
            for t in mc.get("Metadata", []):
                n = t.get("viewCount") or 0
                if not n:
                    break   # sorted by plays, so the rest were never played
                a = t.get("grandparentTitle") or ""
                if a.lower() in ("various artists", "va", "unknown artist", ""):
                    a = t.get("originalTitle") or ""
                if a and a.lower() not in ("various artists", "unknown artist"):
                    plays[a] = plays.get(a, 0) + int(n)
        out = [{"name": a, "mbid": "", "plays": n} for a, n in plays.items()]
        out.sort(key=lambda a: -a["plays"])
        return out[:limit]
    except Exception as e:
        print("[discover] Plex play counts failed:", e, flush=True)
        return []


def _top(user, period, limit):
    """Your top artists for a period. Last.fm's own top-artists call fails ("Operation failed") on some big accounts,
    so fall back to other calls that give the same play counts: signed top artists, then your library (all time) or the
    weekly chart for the last year (12 months). Logs which one worked."""
    tries = [("top artists", lambda: _paged(limit, "user.getTopArtists", user=user, period=period)),
             ("top artists, signed in", lambda: _paged(limit, "user.getTopArtists", user=user, period=period, signed=True))]
    if period == "overall":
        tries.append(("library", lambda: _paged(limit, "library.getArtists", user=user)))
    else:
        now = int(time.time())
        def chart():
            r = _get("user.getWeeklyArtistChart", user=user, **{"from": now - 365 * 86400, "to": now})
            got = []
            for a in _artists(r):
                try:
                    got.append({"name": a["name"], "mbid": a.get("mbid", ""), "plays": int(a.get("playcount", 0))})
                except (KeyError, ValueError, TypeError):
                    pass
            got.sort(key=lambda a: -a["plays"])
            return got[:limit], r.get("message", "empty answer")
        tries.append(("weekly chart, last 12 months", chart))
    for label, fn in tries:
        out, err = fn()
        if out:
            print("[discover] %s: %d artists from Last.fm %s" % (period, len(out), label), flush=True)
            return out
        print("[discover] Last.fm %s (%s) failed: %s" % (label, period, err), flush=True)
    return []


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
        source = "lastfm"
        if not recent and not allt:
            # Last.fm won't hand over your charts right now: use what you've played in Plex so the lists still appear.
            # Last.fm is asked again on the next daily rebuild.
            allt = _plex_top(300)
            source = "plex"
            if not allt:
                _fail("Last.fm wouldn't give the top artists for %s, and Plex had no play counts either" % user)
                return
            print("[discover] using Plex play counts for %d artists until Last.fm answers" % len(allt), flush=True)
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
        misses = 0
        for src in loved[:25]:
            r = _get("artist.getSimilar", artist=src["name"], limit=30, autocorrect=1)
            if r.get("error"):
                misses += 1
                print("[discover] similar to %s failed: %s" % (src["name"], r.get("message", "")), flush=True)
                if misses >= 4 and not rec:
                    break   # Last.fm is refusing these right now; save the loved list rather than wait
                continue
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
            d.update({"loved": loved, "recs": recs, "plays": plays, "built": int(time.time()), "user": user, "source": source})
            if source != "lastfm":
                d["built"] = int(time.time()) - BUILD_EVERY + 3 * 3600   # try Last.fm again in a few hours, not a day
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
