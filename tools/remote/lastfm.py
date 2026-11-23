"""Last.fm scrobbling for Hearth. Standard library only.

The TV never holds a password or secret. Pairing (Last.fm's web auth):
  TV    POST /api/lastfm/begin    -> asks Last.fm for a token, returns the phone page address
  phone GET  /lastfm              -> button to Last.fm, which sends the phone back to /lastfm/done?token=...
  NAS   auth.getSession(token)    -> session key saved in DATA_DIR/lastfm.json (it never expires)
  TV    GET  /api/lastfm/status   -> "connected" and the user name
Plays: Hearth POSTs {type: now | scrobble | love, artist, title, album, duration, ts}. Scrobbles are queued on
disk and sent in batches of up to 50; if Last.fm or the internet is down they wait and retry.

Settings (environment): LASTFM_API_KEY, LASTFM_API_SECRET (from https://www.last.fm/api/account/create),
PUBLIC_URL (default http://192.168.254.41:8765, the address your phone uses to reach this page).
"""
import hashlib
import json
import os
import random
import threading
import time
import urllib.error
import urllib.parse
import urllib.request

DATA_DIR = os.environ.get("DATA_DIR", "/data")
API_KEY = os.environ.get("LASTFM_API_KEY", "")
API_SECRET = os.environ.get("LASTFM_API_SECRET", "")
PUBLIC_URL = os.environ.get("PUBLIC_URL", "http://192.168.254.41:8765").rstrip("/")
API = "https://ws.audioscrobbler.com/2.0/"
UA = "Hearth/1 (https://github.com/elina-studio/hearth)"
FILE = os.path.join(DATA_DIR, "lastfm.json")
lock = threading.RLock()
RETRY = {11, 16, 29}  # Last.fm: service offline, temporarily unavailable, rate limit


def _load():
    try:
        with open(FILE) as fh:
            return json.load(fh)
    except Exception:
        return {}


def _save(d):
    os.makedirs(DATA_DIR, exist_ok=True)
    tmp = FILE + ".tmp"
    with open(tmp, "w") as fh:
        json.dump(d, fh)
    os.replace(tmp, FILE)


def configured():
    return bool(API_KEY and API_SECRET)


def _call(params, post=True):
    p = dict(params)
    p["api_key"] = API_KEY
    sig = "".join(k + str(p[k]) for k in sorted(p)) + API_SECRET
    p["api_sig"] = hashlib.md5(sig.encode("utf-8")).hexdigest()
    p["format"] = "json"
    data = urllib.parse.urlencode(p).encode("utf-8")
    if post:
        req = urllib.request.Request(API, data=data, headers={"User-Agent": UA})
    else:
        req = urllib.request.Request(API + "?" + data.decode(), headers={"User-Agent": UA})
    try:
        with urllib.request.urlopen(req, timeout=10) as r:
            return json.loads(r.read().decode("utf-8", "replace"))
    except urllib.error.HTTPError as e:
        try:
            return json.loads(e.read().decode("utf-8", "replace"))
        except Exception:
            return {"error": 16, "message": "HTTP %d" % e.code}
    except Exception as e:
        return {"error": 16, "message": str(e)}


# ---------------------------------------------------------------- pairing

def begin():
    if not configured():
        return {"ok": False, "error": "Add LASTFM_API_KEY and LASTFM_API_SECRET to the hearth-remote compose file first."}
    r = _call({"method": "auth.getToken"}, post=False)
    if "token" not in r:
        return {"ok": False, "error": r.get("message", "Last.fm didn't answer")}
    with lock:
        d = _load()
        d["pending"] = {"token": r["token"], "at": time.time(), "code": "HRTH-%04d" % random.randint(0, 9999)}
        _save(d)
    return {"ok": True, "code": d["pending"]["code"], "url": PUBLIC_URL + "/lastfm", "expires": 540}


def auth_url():
    d = _load()
    p = d.get("pending")
    if not p or time.time() - p["at"] > 540:
        return None
    cb = PUBLIC_URL + "/lastfm/done"
    return "https://www.last.fm/api/auth/?" + urllib.parse.urlencode({"api_key": API_KEY, "token": p["token"], "cb": cb})


def finish(token):
    r = _call({"method": "auth.getSession", "token": token}, post=False)
    s = r.get("session")
    if not s:
        return False, r.get("message", "Last.fm said no")
    with lock:
        d = _load()
        d["session"] = s["key"]
        d["user"] = s["name"]
        d.pop("pending", None)
        _save(d)
    return True, s["name"]


def disconnect():
    with lock:
        d = _load()
        for k in ("session", "user", "pending"):
            d.pop(k, None)
        _save(d)


def status():
    d = _load()
    today = time.strftime("%Y-%m-%d")
    log = d.get("log", [])
    n = sum(1 for e in log if e.get("day") == today and e.get("ok"))
    st = "off"
    if configured():
        st = "connected" if d.get("session") else ("waiting" if d.get("pending") and time.time() - d["pending"]["at"] < 540 else "idle")
    return {
        "configured": configured(), "state": st, "user": d.get("user", ""),
        "code": (d.get("pending") or {}).get("code", ""), "queued": len(d.get("queue", [])),
        "today": n, "recent": log[-5:][::-1],
    }


# ---------------------------------------------------------------- plays

def event(ev):
    d = _load()
    sk = d.get("session")
    if not (configured() and sk):
        return {"ok": False, "error": "not connected"}
    kind = ev.get("type")
    artist, title = str(ev.get("artist", "")).strip(), str(ev.get("title", "")).strip()
    if not (artist and title):
        return {"ok": False, "error": "no song"}
    album = str(ev.get("album", ""))
    dur = int(float(ev.get("duration") or 0))
    if kind == "now":
        p = {"method": "track.updateNowPlaying", "artist": artist, "track": title, "sk": sk}
        if album:
            p["album"] = album
        if dur:
            p["duration"] = dur
        r = _call(p)
        return {"ok": "error" not in r}
    if kind == "love":
        r = _call({"method": "track.love", "artist": artist, "track": title, "sk": sk})
        return {"ok": "error" not in r}
    if kind == "scrobble":
        ts = int(ev.get("ts") or time.time())
        with lock:
            d = _load()
            q = d.setdefault("queue", [])
            if not any(x["artist"] == artist and x["title"] == title and abs(x["ts"] - ts) < 20 for x in q):
                q.append({"artist": artist, "title": title, "album": album, "duration": dur, "ts": ts})
            _save(d)
        flush()
        return {"ok": True}
    return {"ok": False, "error": "unknown type"}


def flush():
    with lock:
        d = _load()
        sk = d.get("session")
        q = d.get("queue", [])
        if not (sk and q):
            return
        batch = q[:50]
        p = {"method": "track.scrobble", "sk": sk}
        for i, x in enumerate(batch):
            p["artist[%d]" % i] = x["artist"]
            p["track[%d]" % i] = x["title"]
            p["timestamp[%d]" % i] = x["ts"]
            if x.get("album"):
                p["album[%d]" % i] = x["album"]
            if x.get("duration"):
                p["duration[%d]" % i] = x["duration"]
        r = _call(p)
        err = r.get("error")
        if err in RETRY:
            return  # try again later; the queue stays
        if err == 9:  # session no longer valid: ask for pairing again
            d.pop("session", None)
            d.pop("user", None)
            _save(d)
            return
        ok = err is None
        log = d.setdefault("log", [])
        for x in batch:
            log.append({"artist": x["artist"], "title": x["title"], "ts": x["ts"], "day": time.strftime("%Y-%m-%d", time.localtime(x["ts"])), "ok": ok})
        d["log"] = log[-200:]
        d["queue"] = q[len(batch):]
        _save(d)


def worker():
    while True:
        time.sleep(60)
        try:
            flush()
        except Exception as e:
            print("lastfm flush:", e, flush=True)


PAGE = """<!doctype html><meta name=viewport content="width=device-width,initial-scale=1"><title>Hearth and Last.fm</title>
<style>body{background:#0A0E09;color:#EDE6CA;font:20px/1.4 system-ui;margin:0;padding:28px;max-width:560px}
h1{font:italic 34px Georgia,serif;margin:0 0 12px}a.b{display:block;background:#E0B34A;color:#1F1606;font-weight:700;text-align:center;
padding:16px;border-radius:6px;text-decoration:none;margin:24px 0}.m{color:#B5AF8C}</style>
<h1>Last.fm</h1>%s"""


def phone_page():
    if not configured():
        return PAGE % "<p>Last.fm isn't set up on the NAS yet. Add LASTFM_API_KEY and LASTFM_API_SECRET to the hearth-remote compose file.</p>"
    st = status()
    if st["state"] == "connected":
        return PAGE % ("<p>Connected as <b>%s</b>. You can close this page; the TV already knows.</p>" % st["user"])
    u = auth_url()
    if not u:
        return PAGE % "<p>Start from the TV first: Music, then the * options sheet, then Last.fm.</p>"
    return PAGE % ('<p>Code <b>%s</b> (check it matches the TV).</p><a class=b href="%s">Sign in to Last.fm and allow Hearth</a>'
                   '<p class=m>Your password goes to Last.fm only. Hearth never sees it.</p>' % (st["code"], u))


def done_page(token):
    ok, who = finish(token) if token else (False, "No token")
    if ok:
        return PAGE % ("<p>Done. Connected as <b>%s</b>. Look at the TV.</p>" % who)
    return PAGE % ("<p>That didn't work: %s</p><p><a href=/lastfm style=color:#E0B34A>Try again</a></p>" % who)
