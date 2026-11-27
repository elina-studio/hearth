"""IMDb and Rotten Tomatoes scores for the Requests room. Standard library only.

The TV sends the titles on screen (Overseerr / TMDB ids) and gets every score it can show at once:
  POST /api/ratings {"ids": ["movie:603", "tv:1399", ...]}
      -> {"ratings": {"movie:603": {"imdb": 8.7, "rt": 83, "aud": 85, "cert": true}, "tv:1399": {}}, "pending": []}
     An empty {} means "looked, nothing found". Ids still being looked up come back in "pending": ask again shortly.
  GET  /api/ratings/selftest -> plain text, one line per source

Where the scores come from:
  - Overseerr (the key the TV backs up in hearth-keys.json) gives each title's name, year and IMDb id.
  - Rotten Tomatoes: the same public search Overseerr itself uses, asked directly so the audience score comes too.
    If that search fails, Overseerr's own /ratings answer (critics only) is used instead.
  - IMDb: IMDb's free daily ratings file (datasets.imdbws.com, personal use), kept on the NAS in a small
    SQLite file and refreshed weekly. Overseerr 1.33.2 has no IMDb scores of its own.
Everything is cached in DATA_DIR/ratings.json (found: 7 days, not found: 2 days), and a background pass keeps
Trending, Popular and Coming soon warm, so the TV usually gets every score from the cache straight away.
"""
import concurrent.futures
import gzip
import json
import os
import re
import sqlite3
import threading
import time
import urllib.error
import urllib.parse
import urllib.request

DATA_DIR = os.environ.get("DATA_DIR", "/data")
CACHE_FILE = os.path.join(DATA_DIR, "ratings.json")
IMDB_DB = os.path.join(DATA_DIR, "imdb-ratings.sqlite")
IMDB_URL = os.environ.get("IMDB_RATINGS_URL", "https://datasets.imdbws.com/title.ratings.tsv.gz")
RT_URL = "https://79frdp12pn-dsn.algolia.net/1/indexes/*/queries"
RT_HEADERS = {
    "x-algolia-agent": "Algolia%20for%20JavaScript%20(4.14.3)%3B%20Browser%20(lite)",
    "x-algolia-api-key": "175588f6e5f8319b27702e4cc4013561",
    "x-algolia-application-id": "79FRDP12PN",
    "Content-Type": "application/json",
    "Accept": "application/json",
}
FOUND_TTL = 7 * 24 * 3600
MISS_TTL = 2 * 24 * 3600
IMDB_EVERY = 7 * 24 * 3600
WARM_EVERY = 6 * 3600
MIN_VOTES = 25          # an IMDb score from a handful of votes says nothing
WAIT = 8.0              # how long one TV request waits for fresh lookups before answering with what it has

lock = threading.RLock()
_cache = None
_inflight = {}
_pool = concurrent.futures.ThreadPoolExecutor(max_workers=6)
_imdb_state = {"status": "not downloaded yet (the helper fetches it a minute after it starts)", "rows": 0, "at": 0}


# ------------------------------------------------------------------ cache

def _load():
    global _cache
    with lock:
        if _cache is None:
            try:
                with open(CACHE_FILE) as fh:
                    _cache = json.load(fh)
            except Exception:
                _cache = {}
        return _cache


def _save():
    with lock:
        os.makedirs(DATA_DIR, exist_ok=True)
        tmp = CACHE_FILE + ".tmp"
        with open(tmp, "w") as fh:
            json.dump(_cache, fh)
        os.replace(tmp, CACHE_FILE)


def _fresh(e):
    if not e:
        return False
    found = e.get("rt") is not None or e.get("imdbId")
    return time.time() - e.get("at", 0) < (FOUND_TTL if found else MISS_TTL)


# ------------------------------------------------------------------ Overseerr

def _keys():
    try:
        with open(os.path.join(DATA_DIR, "hearth-keys.json")) as fh:
            k = json.load(fh)
    except Exception:
        k = {}
    base = (k.get("overseerrUrl") or os.environ.get("OVERSEERR_URL") or "http://127.0.0.1:5055").rstrip("/")
    return base, k.get("overseerrKey") or os.environ.get("OVERSEERR_KEY", "")


def _overseerr(path):
    """(status, json or None)"""
    base, key = _keys()
    if not key:
        return 0, None
    req = urllib.request.Request(base + path, headers={"X-Api-Key": key, "Accept": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=15) as r:
            return r.status, json.loads(r.read().decode("utf-8", "replace"))
    except urllib.error.HTTPError as e:
        return e.code, None
    except Exception:
        return -1, None


# ------------------------------------------------------------------ Rotten Tomatoes

def _norm(s):
    return re.sub(r"[^a-z0-9]+", "", (s or "").lower().replace("&", "and"))


def _rt_search(name):
    body = json.dumps({"requests": [{"indexName": "content_rt", "query": name,
                                     "params": "filters=isEmsSearchable%20%3D%201&hitsPerPage=20"}]}).encode()
    req = urllib.request.Request(RT_URL, data=body, headers=RT_HEADERS, method="POST")
    with urllib.request.urlopen(req, timeout=15) as r:
        data = json.loads(r.read().decode("utf-8", "replace"))
    for res in data.get("results") or []:
        if res.get("index") == "content_rt":
            return res.get("hits") or []
    return []


def pick_rt(hits, kind, name, year):
    """The hit for this title: same name and year (a year either side, release dates differ by country),
    then the same name alone when only one hit has it. Wrong type (a movie for a show) never counts."""
    want = _norm(name)
    ok = []
    for h in hits:
        t = (h.get("type") or "").lower()
        if t and ((kind == "movie" and "movie" not in t) or (kind == "tv" and "tv" not in t and "series" not in t)):
            continue
        if not isinstance(h.get("rottenTomatoes"), dict):
            continue
        ok.append(h)
    named = [h for h in ok if _norm(h.get("title")) == want or want in [_norm(a) for a in (h.get("titles") or [])]]
    if year:
        for gap in (0, 1):
            for h in named:
                try:
                    if abs(int(h.get("releaseYear") or 0) - year) <= gap:
                        return h
                except (TypeError, ValueError):
                    pass
    if len(named) == 1 and not year:
        return named[0]
    # "Dune" vs "Dune: Part One": a name inside the other, same year only
    if year and want:
        for h in ok:
            t = _norm(h.get("title"))
            try:
                same = int(h.get("releaseYear") or 0) == year
            except (TypeError, ValueError):
                same = False
            if same and t and (want in t or t in want):
                return h
    return None


def _rt(kind, tmdb_id, name, year):
    """{"rt", "aud", "cert"} or {} when RT has nothing; raises when nothing could be asked."""
    try:
        h = pick_rt(_rt_search(name), kind, name, year) if name else None
        if h is None:
            return {}
        r = h["rottenTomatoes"]
        out = {}
        if isinstance(r.get("criticsScore"), (int, float)) and r.get("criticsScore") > 0:
            out["rt"] = int(r["criticsScore"])
            if r.get("certifiedFresh"):
                out["cert"] = True
        if isinstance(r.get("audienceScore"), (int, float)) and r.get("audienceScore") > 0:
            out["aud"] = int(r["audienceScore"])
        return out
    except Exception:
        # the direct search failed (network, changed key): Overseerr's own lookup still gives the critics score
        for path in ("/api/v1/%s/%s/ratingscombined" % (kind, tmdb_id), "/api/v1/%s/%s/ratings" % (kind, tmdb_id)):
            st, d = _overseerr(path)
            if st == 200 and isinstance(d, dict):
                imdb = d.get("imdb") if isinstance(d.get("imdb"), dict) else None
                r = d.get("rt") if isinstance(d.get("rt"), dict) else d
                out = {}
                if isinstance(r.get("criticsScore"), (int, float)):
                    out["rt"] = int(r["criticsScore"])
                    if r.get("criticsRating") == "Certified Fresh":
                        out["cert"] = True
                if isinstance(r.get("audienceScore"), (int, float)):
                    out["aud"] = int(r["audienceScore"])
                if imdb and isinstance(imdb.get("criticsScore"), (int, float)):
                    out["imdbOv"] = float(imdb["criticsScore"])
                return out
            if st == 404:
                return {}
        raise


# ------------------------------------------------------------------ IMDb

def _imdb_db():
    return sqlite3.connect(IMDB_DB, timeout=10)


def imdb_scores(ids):
    """{tt: (rating, votes)} for the ids found in the IMDb file"""
    ids = [i for i in ids if i]
    if not ids or not os.path.exists(IMDB_DB):
        return {}
    out = {}
    try:
        con = _imdb_db()
        for i in range(0, len(ids), 400):
            part = ids[i:i + 400]
            q = "SELECT id, rating, votes FROM r WHERE id IN (%s)" % ",".join("?" * len(part))
            for row in con.execute(q, part):
                out[row[0]] = (row[1], row[2])
        con.close()
    except sqlite3.Error:
        pass
    return out


def load_imdb_file(path):
    """Builds the SQLite file from IMDb's title.ratings.tsv.gz (tconst, averageRating, numVotes)."""
    tmp = IMDB_DB + ".tmp"
    if os.path.exists(tmp):
        os.remove(tmp)
    con = sqlite3.connect(tmp)
    con.execute("CREATE TABLE r (id TEXT PRIMARY KEY, rating REAL, votes INTEGER) WITHOUT ROWID")
    n, batch = 0, []
    with gzip.open(path, "rt", encoding="utf-8", errors="replace") as fh:
        head = fh.readline().strip().split("\t")
        if head[:3] != ["tconst", "averageRating", "numVotes"]:
            con.close()
            os.remove(tmp)
            raise ValueError("not the IMDb ratings file (header %r)" % head[:3])
        for line in fh:
            p = line.rstrip("\n").split("\t")
            if len(p) < 3:
                continue
            try:
                batch.append((p[0], float(p[1]), int(p[2])))
            except ValueError:
                continue
            if len(batch) >= 50000:
                con.executemany("INSERT OR REPLACE INTO r VALUES (?,?,?)", batch)
                n += len(batch)
                batch = []
    if batch:
        con.executemany("INSERT OR REPLACE INTO r VALUES (?,?,?)", batch)
        n += len(batch)
    con.commit()
    con.close()
    os.replace(tmp, IMDB_DB)
    return n


def refresh_imdb(force=False):
    if not force and os.path.exists(IMDB_DB) and time.time() - os.path.getmtime(IMDB_DB) < IMDB_EVERY:
        _imdb_state.update(status="ready", at=os.path.getmtime(IMDB_DB))
        return
    gz = os.path.join(DATA_DIR, "imdb-ratings.tsv.gz")
    try:
        _imdb_state["status"] = "downloading"
        req = urllib.request.Request(IMDB_URL, headers={"User-Agent": "hearth-helper"})
        with urllib.request.urlopen(req, timeout=120) as r, open(gz + ".part", "wb") as out:
            while True:
                b = r.read(1 << 16)
                if not b:
                    break
                out.write(b)
        os.replace(gz + ".part", gz)
        _imdb_state["status"] = "loading"
        n = load_imdb_file(gz)
        os.remove(gz)
        _imdb_state.update(status="ready", rows=n, at=time.time())
        print("[ratings] IMDb ratings file loaded: %d titles" % n, flush=True)
    except Exception as e:
        _imdb_state["status"] = "failed: %s" % e
        print("[ratings] IMDb ratings file failed:", e, flush=True)


# ------------------------------------------------------------------ lookups

def _lookup(key):
    """Fills the cache for one "movie:603" / "tv:1399"."""
    try:
        kind, tid = key.split(":", 1)
        st, d = _overseerr("/api/v1/%s/%s" % (kind, int(tid)))
        if st != 200 or not isinstance(d, dict):
            if st == 404:
                e = {"at": time.time()}
            else:
                return  # Overseerr down or no key: try again next time, cache nothing
        else:
            name = d.get("title") if kind == "movie" else d.get("name")
            date = d.get("releaseDate") if kind == "movie" else d.get("firstAirDate")
            year = int(date[:4]) if date and date[:4].isdigit() else 0
            ext = d.get("externalIds") or {}
            e = {"at": time.time(), "imdbId": d.get("imdbId") or ext.get("imdbId") or ""}
            e.update(_rt(kind, tid, name, year))
        with lock:
            _load()[key] = e
    except Exception as ex:
        print("[ratings] lookup %s failed: %s" % (key, ex), flush=True)
    finally:
        with lock:
            _inflight.pop(key, None)


def _start(key):
    with lock:
        f = _inflight.get(key)
        if f is None:
            f = _pool.submit(_lookup, key)
            _inflight[key] = f
        return f


def _view(e):
    """What the TV gets for one title."""
    out = {}
    for k in ("rt", "aud", "cert"):
        if e.get(k) is not None:
            out[k] = e[k]
    return out


def get(ids, wait=WAIT):
    keys = []
    for i in ids or []:
        i = str(i).strip()
        if re.match(r"^(movie|tv):\d+$", i) and i not in keys:
            keys.append(i)
    keys = keys[:200]
    cache = _load()
    with lock:
        todo = [k for k in keys if not _fresh(cache.get(k))]
    futs = [_start(k) for k in todo]
    if futs:
        concurrent.futures.wait(futs, timeout=wait)
        try:
            _save()
        except OSError:
            pass
    with lock:
        cache = _load()
        ready = {k: cache[k] for k in keys if k in cache}
        pending = [k for k in keys if k not in ready and k in _inflight]
    scores = imdb_scores([e.get("imdbId") for e in ready.values()])
    out = {}
    for k, e in ready.items():
        v = _view(e)
        s = scores.get(e.get("imdbId"))
        if s and s[1] >= MIN_VOTES:
            v["imdb"] = round(s[0], 1)
        elif e.get("imdbOv"):
            v["imdb"] = round(e["imdbOv"], 1)
        out[k] = v
    return {"ratings": out, "pending": pending}


# ------------------------------------------------------------------ background

WARM_LISTS = ["/api/v1/discover/trending", "/api/v1/discover/movies", "/api/v1/discover/tv",
              "/api/v1/discover/movies/upcoming"]


def warm():
    ids = []
    for path in WARM_LISTS:
        for page in (1, 2, 3):
            st, d = _overseerr(path + "?page=%d" % page)
            if st != 200 or not isinstance(d, dict):
                break
            for r in d.get("results") or []:
                kind = r.get("mediaType") or ("movie" if r.get("title") else "tv" if r.get("name") else "")
                if kind in ("movie", "tv") and r.get("id"):
                    ids.append("%s:%s" % (kind, r["id"]))
    if ids:
        get(ids, wait=300)
        print("[ratings] warmed %d titles" % len(ids), flush=True)


def worker():
    time.sleep(20)
    while True:
        try:
            refresh_imdb()
        except Exception as e:
            print("[ratings] imdb refresh:", e, flush=True)
        try:
            warm()
        except Exception as e:
            print("[ratings] warm:", e, flush=True)
        time.sleep(WARM_EVERY)


def selftest():
    lines = []
    base, key = _keys()
    st, d = _overseerr("/api/v1/status")
    lines.append("Overseerr %s: %s" % (base, ("ok, version %s" % d.get("version")) if st == 200 and isinstance(d, dict)
                                       else ("no key backed up on the NAS yet" if not key else "error %s" % st)))
    try:
        h = pick_rt(_rt_search("The Matrix"), "movie", "The Matrix", 1999)
        lines.append("Rotten Tomatoes: ok (The Matrix %s%%)" % h["rottenTomatoes"].get("criticsScore") if h
                     else "Rotten Tomatoes: answered, but no match for The Matrix")
    except Exception as e:
        lines.append("Rotten Tomatoes: failed (%s); Overseerr's critics score is used instead" % e)
    if os.path.exists(IMDB_DB) and _imdb_state["status"].startswith("not downloaded"):
        _imdb_state["status"] = "ready"
    s = imdb_scores(["tt0133093"]).get("tt0133093")
    if s:
        lines.append("IMDb: ok (The Matrix %.1f), file %s" % (s[0], _imdb_state["status"]))
    else:
        lines.append("IMDb: file %s" % _imdb_state["status"])
    with lock:
        n = len(_load())
    lines.append("Cached titles: %d" % n)
    return "\n".join(lines) + "\n"
