"""Hearth Music Discover: what you own, what is missing, and the pictures. Standard library (+ Pillow to shrink pictures).

Lidarr is the truth for artists it manages (every album with "have / asked for / missing"); Plex says what is already
on the shelf for everyone else; Deezer (free, no key) gives discographies and photos for artists Lidarr doesn't know,
with Last.fm's top albums as the fallback. The TV never talks to these itself for Discover: it asks the helper.
  library()            every Lidarr artist with its albums, kept 15 minutes (refreshed in the background)
  albums(artist)       that artist's albums, missing ones first, each marked have / req / miss / ext
  request_album(id)    ask Lidarr to monitor and search one album
  image(...)           one picture (artist photo or album cover), shrunk and kept on the NAS
  selftest()           one line per source saying whether it works from this NAS
"""
import datetime
import hashlib
import io
import ipaddress
import json
import os
import re
import socket
import threading
import time
import urllib.error
import urllib.parse
import urllib.request

import lastfm

IMG_DIR = os.path.join(lastfm.DATA_DIR, "img")
DISCO_FILE = os.path.join(lastfm.DATA_DIR, "disco.json")
SKIP = {"compilation", "live", "remix", "dj-mix", "mixtape/street", "demo", "soundtrack", "spokenword", "interview",
        "audiobook"}
LASTFM_BLANK = "2a96cbd8b46e442fc41c2b86b821562f"
LIB_EVERY = 15 * 60
lock = threading.RLock()
_lib = {"t": 0, "v": None, "busy": False, "error": ""}
_plex = {"t": 0, "v": {}, "artists": set(), "error": ""}
_disco_lock = threading.RLock()


def norm(t):
    return "".join(ch for ch in (t or "").lower() if ch.isalnum())


def base_title(t):
    """'Eureka (Deluxe Edition) [Remastered]' -> 'eureka', so editions match what's on the shelf."""
    full = t or ""
    t = re.sub(r"[\(\[][^\)\]]*[\)\]]", "", full)
    t = re.sub(r"\s+-\s+(deluxe|remaster|expanded|anniversary|bonus|special).*$", "", t, flags=re.I)
    return norm(t) or norm(full)


def _keys():
    import web
    return web.keys()


# ---------------------------------------------------------------- Lidarr
def _lidarr(path, method="GET", body=None, timeout=90, raw=False):
    k = _keys()
    key = k.get("lidarrKey") or ""
    if not key:
        raise RuntimeError("no Lidarr key saved on the helper (run the setup command)")
    url = (k.get("lidarrUrl") or "http://192.168.254.41:8686").rstrip("/") + path
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method,
                                 headers={"X-Api-Key": key, "Content-Type": "application/json", "Accept": "*/*"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        b = r.read(64 * 1024 * 1024)
        if raw:
            return b, r.headers.get("Content-Type", "")
        return json.loads(b.decode("utf-8", "replace")) if b else {}


def _album_row(a):
    st = a.get("statistics") or {}
    files = int(st.get("trackFileCount") or 0)
    tracks = int(st.get("trackCount") or st.get("totalTrackCount") or 0)
    sec = {str(s).lower() for s in (a.get("secondaryTypes") or [])}
    day = (a.get("releaseDate") or "")[:10]
    remote = ""
    for im in a.get("images") or []:
        if (im.get("coverType") or "").lower() == "cover" and im.get("remoteUrl"):
            remote = im["remoteUrl"]
    # "have" = at least half the tracks are on disk (a stray single track from a compilation doesn't count)
    have = files > 0 and (tracks == 0 or files * 2 >= tracks)
    return {"id": a.get("id", 0), "title": a.get("title", ""), "date": day, "year": day[:4],
            "kind": (a.get("albumType") or "Album").lower(), "extra": bool(sec),
            "have": have, "mon": bool(a.get("monitored")), "rgid": a.get("foreignAlbumId", ""), "remote": remote,
            "aid": a.get("artistId", 0)}


def _load_library():
    """{'artists': {norm name: {...}}, 'albums': {artist id: [rows]}} straight from Lidarr."""
    arts = _lidarr("/api/v1/artist")
    if not isinstance(arts, list):
        raise RuntimeError("Lidarr didn't list its artists")
    try:
        allb = _lidarr("/api/v1/album", timeout=180)
        if not isinstance(allb, list):
            raise ValueError("not a list")
    except Exception as e:
        print("[shelf] Lidarr wouldn't give every album at once (%s); asking artist by artist" % e, flush=True)
        allb = []
        for a in arts:
            try:
                got = _lidarr("/api/v1/album?artistId=%d" % a["id"], timeout=30)
                if isinstance(got, list):
                    allb.extend(got)
            except Exception:
                pass
    by = {}
    for a in allb:
        row = _album_row(a)
        by.setdefault(row["aid"], []).append(row)
    out = {}
    for a in arts:
        remote = ""
        for im in a.get("images") or []:
            if (im.get("coverType") or "").lower() == "poster" and im.get("remoteUrl"):
                remote = im["remoteUrl"]
        out[norm(a.get("artistName", ""))] = {"id": a["id"], "name": a.get("artistName", ""), "remote": remote,
                                              "mbid": a.get("foreignArtistId", "")}
    return {"artists": out, "albums": by}


def _refresh_library():
    try:
        v = _load_library()
        with lock:
            _lib.update(t=time.time(), v=v, error="")
        print("[shelf] Lidarr: %d artists, %d albums" % (len(v["artists"]), sum(len(x) for x in v["albums"].values())),
              flush=True)
    except Exception as e:
        with lock:
            _lib.update(t=time.time() - LIB_EVERY + 120, error="%s" % e)   # try again in two minutes
        print("[shelf] Lidarr library failed:", e, flush=True)
    finally:
        _lib["busy"] = False


def library(wait=False):
    """The Lidarr library, or None while the first read is still running. Never blocks unless wait=True."""
    with lock:
        stale = time.time() - _lib["t"] > LIB_EVERY
        start = stale and not _lib["busy"]
        if start:
            _lib["busy"] = True
    if start:
        if wait:
            _refresh_library()
        else:
            threading.Thread(target=_refresh_library, daemon=True).start()
    elif wait:
        for _ in range(240):
            if not _lib["busy"]:
                break
            time.sleep(0.5)
    return _lib["v"]


def library_state():
    return {"ready": _lib["v"] is not None, "busy": _lib["busy"], "error": _lib["error"]}


def invalidate():
    _lib["t"] = 0
    _plex["t"] = 0


def _state(row, shelf):
    """have / req (asked for, not here yet) / soon (not out yet) / miss."""
    if row["have"] or base_title(row["title"]) in shelf:
        return "have"
    if row["date"] and row["date"] > datetime.date.today().isoformat():
        return "soon"
    return "req" if row["mon"] else "miss"


def _wanted(row):
    """Counts toward "missing": a real album or EP, not a live record, compilation, single..."""
    return row["kind"] in ("album", "ep") and not row["extra"]


def lidarr_albums(entry, lib):
    """One Lidarr artist's albums and EPs for the TV, missing first then newest first."""
    shelf = plex_albums().get(norm(entry["name"]), set())
    out = []
    for row in lib["albums"].get(entry["id"], []):
        if not _wanted(row):
            continue
        st = _state(row, shelf)
        out.append({"title": row["title"], "year": row["year"], "kind": row["kind"], "state": st, "id": row["id"],
                    "img": "/api/discover/img?album=%d" % row["id"]})
    order = {"miss": 0, "req": 1, "soon": 2, "have": 3}
    out.sort(key=lambda a: a["year"] or "0000", reverse=True)
    out.sort(key=lambda a: order[a["state"]])
    return out


def summary():
    """{norm name: {name, lid, togo, albums}} for every Lidarr artist; {} until Lidarr has answered."""
    lib = library()
    if not lib:
        return {}
    shelves = plex_albums()
    out = {}
    for key, e in lib["artists"].items():
        shelf = shelves.get(key, set())
        togo = total = have = 0
        for row in lib["albums"].get(e["id"], []):
            if not _wanted(row):
                continue
            st = _state(row, shelf)
            if st == "soon":
                continue
            total += 1
            if st == "miss":
                togo += 1
            elif st == "have":
                have += 1
        out[key] = {"name": e["name"], "lid": e["id"], "togo": togo, "albums": total, "have": have}
    return out


def recent(back=60, ahead=180):
    """Lidarr albums and EPs out in the last `back` days or due in the next `ahead`."""
    lib = library()
    if not lib:
        return []
    today = datetime.date.today()
    lo, hi = (today - datetime.timedelta(days=back)).isoformat(), (today + datetime.timedelta(days=ahead)).isoformat()
    names = {e["id"]: e["name"] for e in lib["artists"].values()}
    shelves = plex_albums()
    out = []
    for aid, rows in lib["albums"].items():
        name = names.get(aid, "")
        for row in rows:
            if not _wanted(row) or not (lo <= row["date"] <= hi):
                continue
            out.append({"title": row["title"], "artist": name, "date": row["date"], "kind": row["kind"],
                        "state": _state(row, shelves.get(norm(name), set())), "id": row["id"],
                        "img": "/api/discover/img?album=%d" % row["id"]})
    return out


def request_album(album_id):
    """Ask Lidarr for one album: monitor it and start a search."""
    try:
        album_id = int(album_id)
    except (TypeError, ValueError):
        return {"ok": False, "error": "no album given"}
    if album_id <= 0:
        return {"ok": False, "error": "no album given"}
    try:
        _lidarr("/api/v1/album/monitor", "PUT", {"albumIds": [album_id], "monitored": True}, timeout=20)
        _lidarr("/api/v1/command", "POST", {"name": "AlbumSearch", "albumIds": [album_id]}, timeout=20)
    except urllib.error.HTTPError as e:
        return {"ok": False, "error": "Lidarr said no (%d)" % e.code}
    except Exception as e:
        return {"ok": False, "error": "Lidarr didn't answer: %s" % e}
    lib = _lib["v"]
    if lib:
        for rows in lib["albums"].values():
            for row in rows:
                if row["id"] == album_id:
                    row["mon"] = True
    return {"ok": True}


def request_missing(name):
    """Ask Lidarr for every missing album and EP of one artist it already knows. One search command for the lot."""
    lib = library(wait=True)
    e = (lib or {}).get("artists", {}).get(norm(name))
    if not e:
        return {"ok": False, "error": "Lidarr doesn't have %s yet" % name}
    ids = [a["id"] for a in lidarr_albums(e, lib) if a["state"] == "miss"]
    if not ids:
        return {"ok": True, "asked": 0}
    try:
        _lidarr("/api/v1/album/monitor", "PUT", {"albumIds": ids, "monitored": True}, timeout=30)
        _lidarr("/api/v1/command", "POST", {"name": "AlbumSearch", "albumIds": ids}, timeout=30)
    except urllib.error.HTTPError as ex:
        return {"ok": False, "error": "Lidarr said no (%d)" % ex.code}
    except Exception as ex:
        return {"ok": False, "error": "Lidarr didn't answer: %s" % ex}
    want = set(ids)
    for row in lib["albums"].get(e["id"], []):
        if row["id"] in want:
            row["mon"] = True
    return {"ok": True, "asked": len(ids)}


# ---------------------------------------------------------------- Plex
def _plex_get(path, timeout=60):
    k = _keys()
    tok = k.get("plexServerToken") or k.get("plexToken") or ""
    if not tok:
        raise RuntimeError("no Plex token saved on the helper (run the setup command)")
    base = (k.get("plexServer") or "http://192.168.254.41:32400").rstrip("/")
    sep = "&" if "?" in path else "?"
    req = urllib.request.Request(base + path + sep + "X-Plex-Token=" + urllib.parse.quote(tok),
                                 headers={"Accept": "application/json"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read().decode("utf-8", "replace")).get("MediaContainer", {})


def plex_albums():
    """{norm artist: set of base album titles} for every Plex music library (kept 10 minutes)."""
    if time.time() - _plex["t"] < 600:
        return _plex["v"]
    have = {}
    try:
        for sec in _plex_get("/library/sections").get("Directory", []):
            if sec.get("type") == "artist":
                for al in _plex_get("/library/sections/%s/all?type=9" % sec["key"]).get("Metadata", []):
                    have.setdefault(norm(al.get("parentTitle", "")), set()).add(base_title(al.get("title", "")))
        _plex.update(t=time.time(), v=have, error="")
    except Exception as e:
        _plex.update(t=time.time() - 480, error="%s" % e)   # keep the old answer, try again in two minutes
        print("[shelf] Plex album list failed:", e, flush=True)
    return _plex["v"]


# ---------------------------------------------------------------- Deezer / Last.fm discographies
def _deezer(path):
    req = urllib.request.Request("https://api.deezer.com" + path, headers={"User-Agent": lastfm.UA})
    try:
        with urllib.request.urlopen(req, timeout=15) as r:
            return json.loads(r.read().decode("utf-8", "replace"))
    except Exception:
        return {}


def deezer_artist(name):
    """(Deezer id, photo url) matched on the exact name; (0, "") if Deezer doesn't know them or can't be reached."""
    r = _deezer("/search/artist?" + urllib.parse.urlencode({"q": name, "limit": 5}))
    for a in r.get("data") or []:
        if norm(a.get("name", "")) == norm(name):
            pic = a.get("picture_big") or a.get("picture_medium") or ""
            return a.get("id", 0), ("" if "/artist//" in pic else pic)
    return 0, ""


def _deezer_disco(aid):
    r = _deezer("/artist/%s/albums?limit=200" % aid)
    out, seen = [], set()
    for a in sorted(r.get("data") or [], key=lambda a: a.get("release_date", ""), reverse=True):
        kind = a.get("record_type", "")
        if kind not in ("album", "ep"):
            continue
        k = base_title(a.get("title", ""))
        if not k or k in seen:
            continue
        seen.add(k)
        out.append({"title": a.get("title", ""), "year": (a.get("release_date") or "")[:4], "kind": kind,
                    "cover": a.get("cover_big") or a.get("cover_medium") or ""})
    return out


def _lastfm_disco(name):
    import discover
    r = discover._get("artist.getTopAlbums", artist=name, limit=12, autocorrect=1)
    out, seen = [], set()
    for a in (r.get("topalbums", {}).get("album") or []):
        n = a.get("name", "")
        k = base_title(n)
        if not n or n == "(null)" or not k or k in seen:
            continue
        seen.add(k)
        img = ""
        for im in a.get("image") or []:
            u = im.get("#text", "")
            if u and LASTFM_BLANK not in u:
                img = u
        out.append({"title": n, "year": "", "kind": "album", "cover": img})
    return out


def _disco_load():
    try:
        with open(DISCO_FILE) as fh:
            return json.load(fh)
    except Exception:
        return {}


def _disco_save(d):
    os.makedirs(lastfm.DATA_DIR, exist_ok=True)
    with open(DISCO_FILE + ".tmp", "w") as fh:
        json.dump(d, fh)
    os.replace(DISCO_FILE + ".tmp", DISCO_FILE)


def disco_cached(name, d=None):
    """The saved discography for an artist Lidarr doesn't manage, or None if it hasn't been looked up yet."""
    hit = (_disco_load() if d is None else d).get(norm(name))
    return hit if hit and time.time() - hit.get("t", 0) < 14 * 86400 else None


def discography(name):
    """Albums and EPs for an artist Lidarr doesn't manage: Deezer first, Last.fm's top albums if Deezer has nothing.
    Saved for two weeks (an empty answer for a day, so an outage heals)."""
    hit = disco_cached(name)
    if hit and (hit["a"] or time.time() - hit["t"] < 86400):
        return hit
    aid, pic = deezer_artist(name)
    lst = _deezer_disco(aid) if aid else []
    src = "deezer"
    if not lst:
        lst, src = _lastfm_disco(name), "lastfm"
    hit = {"t": time.time(), "a": lst, "pic": pic, "src": src if lst else ""}
    with _disco_lock:
        d = _disco_load()
        d[norm(name)] = hit
        _disco_save(d)
    return hit


def ext_albums(name, hit):
    shelf = plex_albums().get(norm(name), set())
    out = []
    for a in hit.get("a") or []:
        img = ("/api/discover/img?u=" + urllib.parse.quote(a["cover"], safe="")) if a.get("cover") else ""
        out.append({"title": a["title"], "year": a.get("year", ""), "kind": a.get("kind", "album"), "id": 0,
                    "state": "have" if base_title(a["title"]) in shelf else "ext", "img": img})
    out.sort(key=lambda a: a["state"] == "have")
    return out


def albums(name):
    """What the TV shows on an artist's shelf: {albums, togo, total, lid, source}."""
    lib = library(wait=True)
    e = (lib or {}).get("artists", {}).get(norm(name))
    if e:
        lst = lidarr_albums(e, lib)
        if lst:
            return {"albums": lst, "lid": e["id"], "source": "lidarr",
                    "togo": sum(1 for a in lst if a["state"] == "miss"),
                    "total": sum(1 for a in lst if a["state"] != "soon")}
    lst = ext_albums(name, discography(name))
    return {"albums": lst, "lid": e["id"] if e else 0, "source": "web",
            "togo": sum(1 for a in lst if a["state"] != "have"), "total": len(lst)}


# ---------------------------------------------------------------- pictures
IMG_HOSTS = (".dzcdn.net", "lastfm.freetls.fastly.net", ".last.fm", "coverartarchive.org", ".archive.org",
             ".fanart.tv", ".theaudiodb.com", ".discogs.com", ".musicbrainz.org", ".spotifycdn.com", ".scdn.co",
             "imagecache.lidarr.audio", ".lidarr.audio")


def _public(url):
    """Only fetch pictures from the music picture hosts, and never from an address inside the house."""
    u = urllib.parse.urlsplit(url)
    host = (u.hostname or "").lower()
    if u.scheme not in ("http", "https") or not any(host == h.lstrip(".") or host.endswith(h) for h in IMG_HOSTS):
        return False
    try:
        for info in socket.getaddrinfo(host, None):
            ip = ipaddress.ip_address(info[4][0])
            if ip.is_private or ip.is_loopback or ip.is_link_local or ip.is_reserved or ip.is_multicast:
                return False
    except Exception:
        return False
    return True


def _fetch(url):
    if not _public(url):
        return None
    try:
        req = urllib.request.Request(url, headers={"User-Agent": lastfm.UA})
        with urllib.request.urlopen(req, timeout=20) as r:
            if not r.headers.get("Content-Type", "").startswith("image/"):
                return None
            return r.read(8 * 1024 * 1024)
    except Exception:
        return None


def _lidarr_img(paths):
    for p in paths:
        try:
            b, ctype = _lidarr(p, timeout=15, raw=True)
            if b and ctype.startswith("image/"):
                return b
        except Exception:
            continue
    return None


def _shrink(body, size=320):
    try:
        from PIL import Image
        im = Image.open(io.BytesIO(body))
        im = im.convert("RGB")
        w, h = im.size
        s = min(w, h)
        im = im.crop(((w - s) // 2, (h - s) // 2, (w - s) // 2 + s, (h - s) // 2 + s))
        if s > size:
            im = im.resize((size, size))
        out = io.BytesIO()
        im.save(out, "JPEG", quality=85)
        return out.getvalue()
    except Exception:
        return body if body[:3] == b"\xff\xd8\xff" else None   # the TV can show a plain JPEG as it is


def _artist_image(name):
    lib = library()
    e = (lib or {}).get("artists", {}).get(norm(name))
    if e:
        b = _lidarr_img(["/api/v1/mediacover/artist/%d/poster-500.jpg" % e["id"],
                         "/api/v1/mediacover/artist/%d/poster.jpg" % e["id"],
                         "/MediaCover/%d/poster-500.jpg" % e["id"], "/MediaCover/%d/poster.jpg" % e["id"]])
        if not b and e.get("remote"):
            b = _fetch(e["remote"])
        if b:
            return b
    hit = disco_cached(name)
    pic = hit.get("pic", "") if hit else deezer_artist(name)[1]
    if not pic and hit and "pic" not in hit:
        pic = deezer_artist(name)[1]
    return _fetch(pic) if pic else None


def _album_image(album_id):
    b = _lidarr_img(["/api/v1/mediacover/album/%d/cover-500.jpg" % album_id,
                     "/api/v1/mediacover/album/%d/cover.jpg" % album_id,
                     "/MediaCover/Albums/%d/cover-500.jpg" % album_id, "/MediaCover/Albums/%d/cover.jpg" % album_id])
    if b:
        return b
    lib = _lib["v"]
    for rows in (lib or {}).get("albums", {}).values():
        for row in rows:
            if row["id"] == album_id:
                if row.get("remote"):
                    b = _fetch(row["remote"])
                if not b and row.get("rgid"):
                    b = _fetch("https://coverartarchive.org/release-group/%s/front-500" % row["rgid"])
                return b
    return None


def image(artist="", album="", url="", rg=""):
    """(JPEG bytes or None) for one picture: an artist photo, a Lidarr album cover, a release-group cover, or a
    picture address from Deezer / Last.fm. Kept in DATA_DIR/img; a miss is remembered for a day."""
    if artist:
        key = "a:" + norm(artist)
    elif album:
        key = "l:%s" % album
    elif rg:
        key = "r:" + rg
    elif url:
        key = "u:" + url
    else:
        return None
    os.makedirs(IMG_DIR, exist_ok=True)
    f = os.path.join(IMG_DIR, hashlib.sha1(key.encode()).hexdigest())
    try:
        if os.path.exists(f):
            with open(f, "rb") as fh:
                return fh.read()
        if os.path.exists(f + ".no") and time.time() - os.path.getmtime(f + ".no") < 86400:
            return None
    except OSError:
        pass
    body = None
    try:
        if artist:
            body = _artist_image(artist)
        elif album:
            body = _album_image(int(album))
        elif rg:
            if re.fullmatch(r"[0-9a-fA-F-]{36}", rg):
                body = _fetch("https://coverartarchive.org/release-group/%s/front-500" % rg)
        else:
            body = _fetch(url)
    except Exception as e:
        print("[shelf] picture failed:", e, flush=True)
    body = _shrink(body) if body else None
    try:
        if body:
            with open(f + ".tmp", "wb") as fh:
                fh.write(body)
            os.replace(f + ".tmp", f)
        elif artist and _lib["v"] is None:
            pass   # Lidarr hasn't answered yet: don't remember this miss
        else:
            open(f + ".no", "w").close()
    except OSError:
        pass
    return body


# ---------------------------------------------------------------- self-check
def selftest():
    """[(what, ok, detail)] : does each thing Discover leans on work from this NAS right now?"""
    import discover
    import web
    web._keys["t"] = 0     # read the keys file again: the setup command has just rewritten it
    invalidate()
    out = []

    def check(label, fn):
        try:
            out.append((label, True, fn()))
        except Exception as e:
            out.append((label, False, ("%s" % e)[:140]))

    def t_lidarr():
        lib = library(wait=True)
        if not lib:
            raise RuntimeError(_lib["error"] or "no answer")
        s = summary()
        return "%d artists, %d with albums to get" % (len(lib["artists"]), sum(1 for v in s.values() if v["togo"]))

    def t_plex():
        _plex["t"] = 0
        v = plex_albums()
        if _plex["error"]:
            raise RuntimeError(_plex["error"])
        return "%d artists on the shelf" % len(v)

    def t_lastfm():
        user = lastfm._load().get("user", "")
        if not user:
            raise RuntimeError("not paired")
        r = discover._get("user.getTopArtists", tries=1, user=user, period="overall", limit=1)
        if r.get("error"):
            raise RuntimeError("paired as %s, but your charts fail: %s (lists use Plex play counts meanwhile)"
                               % (user, r.get("message", "")))
        return "charts for %s" % user

    def t_similar():
        r = discover._get("artist.getSimilar", tries=1, artist="Radiohead", limit=1)
        if r.get("error"):
            raise RuntimeError(r.get("message", "failed"))
        return "ok"

    def t_deezer():
        aid, pic = deezer_artist("Radiohead")
        if not aid:
            raise RuntimeError("can't reach Deezer (photos fall back to Lidarr's own)")
        return "ok"

    def t_mb():
        r = discover._mb("arid:a74b1b7f-71a5-4011-9441-d0b5e4122711 AND primarytype:album")
        if not r.get("release-groups"):
            raise RuntimeError("no answer")
        return "ok"

    def t_pic():
        lib = _lib["v"]
        if not lib or not lib["artists"]:
            raise RuntimeError("no Lidarr artists to try")
        tried = 0
        for e in list(lib["artists"].values())[:8]:
            tried += 1
            if _artist_image(e["name"]):
                return "ok (%s)" % e["name"]
        raise RuntimeError("none of %d artists gave a photo" % tried)

    def t_cover():
        lib = _lib["v"]
        n = 0
        for rows in (lib or {}).get("albums", {}).values():
            for row in rows:
                if row["have"]:
                    n += 1
                    if _album_image(row["id"]):
                        return "ok (%s)" % row["title"]
                    if n >= 6:
                        raise RuntimeError("none of %d albums gave a cover" % n)
        raise RuntimeError("no albums to try")

    check("Lidarr (what you have and what's missing)", t_lidarr)
    check("Plex (your shelf)", t_plex)
    check("Last.fm (your charts)", t_lastfm)
    check("Last.fm (similar artists)", t_similar)
    check("Deezer (photos, albums of new artists)", t_deezer)
    check("MusicBrainz (new releases)", t_mb)
    check("Artist photos", t_pic)
    check("Album covers", t_cover)
    return out


def selftest_text():
    lines = []
    for label, ok, detail in selftest():
        lines.append("  %s %s: %s" % ("OK  " if ok else "FAIL", label, detail))
    return "\n".join(lines) + "\n"
