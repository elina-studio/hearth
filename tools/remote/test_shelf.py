"""Tests for the Discover helper against a pretend Lidarr and Plex. Run: python3 test_shelf.py"""
import io
import json
import os
import sys
import tempfile
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

TMP = tempfile.mkdtemp()
os.environ["DATA_DIR"] = TMP
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from PIL import Image

def jpeg(size=600):
    b = io.BytesIO()
    Image.new("RGB", (size, size - 100), (90, 120, 60)).save(b, "JPEG")
    return b.getvalue()

FUTURE = time.strftime("%Y-%m-%d", time.gmtime(time.time() + 30 * 86400))
NEWISH = time.strftime("%Y-%m-%d", time.gmtime(time.time() - 10 * 86400))
ARTISTS = [{"id": 1, "artistName": "Mother Mother", "foreignArtistId": "mm", "images": []},
           {"id": 2, "artistName": "Antonio Vivaldi", "foreignArtistId": "av", "images": []},
           {"id": 3, "artistName": "Big Thief", "foreignArtistId": "bt",
            "images": [{"coverType": "poster", "url": "/MediaCover/3/poster.jpg", "remoteUrl": "https://x.dzcdn.net/bt.jpg"}]}]

def alb(i, aid, title, files, tracks=10, typ="Album", sec=(), date="2015-03-01", mon=False):
    return {"id": i, "artistId": aid, "title": title, "albumType": typ, "secondaryTypes": list(sec), "releaseDate": date + "T00:00:00Z",
            "monitored": mon, "foreignAlbumId": "11111111-2222-3333-4444-%012d" % i, "images": [],
            "statistics": {"trackFileCount": files, "trackCount": tracks}}

ALBUMS = [alb(10, 1, "O My Heart", 10), alb(11, 1, "Eureka", 12, 12), alb(12, 1, "Live at the Hall", 0, sec=["Live"]),
          alb(13, 1, "Some Single", 0, typ="Single")]
ALBUMS += [alb(100 + n, 2, "Concerto Set %d" % n, 0) for n in range(40)]
ALBUMS += [alb(30, 3, "Masterpiece", 9, 12), alb(31, 3, "Capacity", 0), alb(32, 3, "U.F.O.F.", 0, mon=True),
           alb(33, 3, "Two Hands (Deluxe)", 0), alb(34, 3, "Next One", 0, date=FUTURE), alb(35, 3, "Fresh EP", 0, typ="EP", date=NEWISH),
           alb(36, 3, "One Track Only", 1, 12)]
PLEX = [("Mother Mother", "O My Heart"), ("Big Thief", "Two Hands"), ("Elliott Smith", "Either/Or"), ("Elliott Smith", "XO")]
calls = []

class H(BaseHTTPRequestHandler):
    def log_message(self, *a):
        pass
    def out(self, obj, ctype="application/json"):
        b = obj if isinstance(obj, bytes) else json.dumps(obj).encode()
        self.send_response(200); self.send_header("Content-Type", ctype); self.send_header("Content-Length", str(len(b))); self.end_headers(); self.wfile.write(b)
    def do_GET(self):
        p = self.path
        calls.append(("GET", p))
        if p.startswith("/api/v1/artist"):
            assert self.headers.get("X-Api-Key") == "lk"
            return self.out(ARTISTS)
        if p.startswith("/api/v1/album"):
            if "artistId=" in p:
                aid = int(p.split("artistId=")[1])
                return self.out([a for a in ALBUMS if a["artistId"] == aid])
            if H.all_fails:
                self.send_response(500); self.end_headers(); return
            return self.out(ALBUMS)
        if p.startswith("/api/v1/mediacover/album/10/"):
            return self.out(jpeg(), "image/jpeg")
        if p.startswith("/MediaCover/1/poster"):          # only the old-style path works for this artist
            return self.out(jpeg(), "image/jpeg")
        if p.startswith("/library/sections/5/all"):
            return self.out({"MediaContainer": {"Metadata": [{"parentTitle": a, "title": t} for a, t in PLEX]}})
        if p.startswith("/library/sections"):
            assert "X-Plex-Token=pt" in p
            return self.out({"MediaContainer": {"Directory": [{"type": "artist", "key": "5"}, {"type": "movie", "key": "1"}]}})
        self.send_response(404); self.end_headers()
    def do_PUT(self):
        n = int(self.headers.get("Content-Length", 0)); calls.append(("PUT", self.path, json.loads(self.rfile.read(n)))); self.out({})
    do_POST = do_PUT
H.all_fails = False

srv = ThreadingHTTPServer(("127.0.0.1", 0), H)
threading.Thread(target=srv.serve_forever, daemon=True).start()
base = "http://127.0.0.1:%d" % srv.server_port
with open(os.path.join(TMP, "hearth-keys.json"), "w") as fh:
    json.dump({"lidarrUrl": base, "lidarrKey": "lk", "plexServer": base, "plexToken": "pt"}, fh)
import web
web.DATA_DIR = TMP
import lastfm, shelf, discover

fetched = []
DEEZER = {"elliottsmith": (7, "https://e.dzcdn.net/images/artist/es/500.jpg"), "newband": (8, "https://e.dzcdn.net/images/artist//500.jpg")}
def fake_deezer(path):
    if path.startswith("/search/artist"):
        q = path.split("q=")[1].split("&")[0].replace("+", " ")
        k = shelf.norm(q)
        if k in DEEZER:
            return {"data": [{"id": DEEZER[k][0], "name": q, "picture_big": DEEZER[k][1]}]}
        return {"data": []}
    if path.startswith("/artist/7/albums"):
        return {"data": [{"title": "Either/Or", "record_type": "album", "release_date": "1997-02-25", "cover_big": "https://e.dzcdn.net/c/eo.jpg"},
                         {"title": "XO (Deluxe Edition)", "record_type": "album", "release_date": "1998-08-25", "cover_big": "https://e.dzcdn.net/c/xo.jpg"},
                         {"title": "XO", "record_type": "album", "release_date": "1998-08-24", "cover_big": ""},
                         {"title": "A Single", "record_type": "single", "release_date": "1999-01-01"}]}
    if path.startswith("/artist/8/albums"):
        return {"data": [{"title": "Debut", "record_type": "album", "release_date": "2024-01-01", "cover_big": "https://e.dzcdn.net/c/d.jpg"},
                         {"title": "Second", "record_type": "ep", "release_date": "2025-01-01", "cover_big": ""}]}
    return {}
shelf._deezer = fake_deezer
def fake_fetch(url):
    fetched.append(url)
    return jpeg() if shelf._public(url) or "dzcdn" in url or "coverartarchive" in url else None
real_public = shelf._public
discover._get = lambda method, **kw: {"topalbums": {"album": [{"name": "Only On Lastfm", "image": [{"#text": "https://lastfm.freetls.fastly.net/i/u/300x300/abc.jpg"}]}]}} if method == "artist.getTopAlbums" else {}

def check(name, cond):
    print(("ok   " if cond else "FAIL ") + name)
    if not cond:
        check.bad += 1
check.bad = 0

# --- titles
check("deluxe editions match", shelf.base_title("Two Hands (Deluxe)") == shelf.base_title("Two Hands") == "twohands")
check("a title that is only brackets keeps its name", shelf.base_title("[Untitled]") == "untitled")

# --- library
lib = shelf.library(wait=True)
check("Lidarr library read", lib and len(lib["artists"]) == 3)
s = shelf.summary()
check("Mother Mother has nothing left to get (live + single ignored)", s["mothermother"]["togo"] == 0 and s["mothermother"]["albums"] == 2)
check("Vivaldi: 40 to get", s["antoniovivaldi"]["togo"] == 40)
bt = s["bigthief"]
check("Big Thief: missing = Capacity, Fresh EP, One Track Only (Plex has Two Hands, U.F.O.F. asked for, Next One not out): %r" % bt, bt["togo"] == 3 and bt["albums"] == 6)
a = shelf.albums("big thief")
st = {x["title"]: x["state"] for x in a["albums"]}
check("album states %r" % st, st == {"Capacity": "miss", "Fresh EP": "miss", "One Track Only": "miss", "U.F.O.F.": "req", "Next One": "soon", "Masterpiece": "have", "Two Hands (Deluxe)": "have"})
check("missing albums come first", [x["state"] for x in a["albums"]][:3] == ["miss"] * 3 and a["albums"][-1]["state"] == "have")
check("albums carry Lidarr ids and picture paths", all(x["id"] and x["img"].startswith("/api/discover/img?album=") for x in a["albums"]) and a["togo"] == 3)
new = shelf.recent()
check("new releases: the EP out 10 days ago and the one due in 30: %r" % [(n["title"], n["state"]) for n in new], sorted((n["title"], n["state"]) for n in new) == [("Fresh EP", "miss"), ("Next One", "soon")])

# --- artists Lidarr doesn't have
e = shelf.albums("Elliott Smith")
check("Elliott Smith (not in Lidarr): both albums on the Plex shelf, deluxe twin folded: %r" % e, e["togo"] == 0 and e["total"] == 2 and all(x["state"] == "have" for x in e["albums"]))
n = shelf.albums("New Band")
check("New Band: two albums to get, marked ext", n["togo"] == 2 and all(x["state"] == "ext" for x in n["albums"]) and any(x["img"].startswith("/api/discover/img?u=https%3A%2F%2F") for x in n["albums"]))
l = shelf.albums("Nobody Deezer Knows")
check("unknown to Deezer: falls back to Last.fm top albums", l["total"] == 1 and l["albums"][0]["title"] == "Only On Lastfm")

# --- requests
calls.clear()
r = shelf.request_album(31)
check("request one album: monitor then search", r["ok"] and calls[0][:2] == ("PUT", "/api/v1/album/monitor") and calls[0][2] == {"albumIds": [31], "monitored": True} and calls[1][2] == {"name": "AlbumSearch", "albumIds": [31]})
check("it shows as asked-for straight away", {x["title"]: x["state"] for x in shelf.albums("Big Thief")["albums"]}["Capacity"] == "req")
check("bad album id refused", not shelf.request_album("x")["ok"] and not shelf.request_album(0)["ok"])
calls.clear()
r = shelf.request_missing("Big Thief")
check("get all missing: one command for the two left: %r" % r, r["ok"] and r["asked"] == 2 and sorted(calls[-1][2]["albumIds"]) == [35, 36])
check("artist Lidarr doesn't have: clear error", not shelf.request_missing("New Band")["ok"])

# --- pictures
check("picture host allowlist blocks the house and strangers", not real_public("http://192.168.254.41:8686/x.jpg") and not real_public("https://evil.example/x.jpg") and not real_public("file:///etc/passwd") and not real_public("http://localhost.dzcdn.net.evil.com/x"))
shelf._fetch = fake_fetch
b = shelf.image(album="10")
im = Image.open(io.BytesIO(b))
check("Lidarr album cover, cropped square and shrunk: %r" % (im.size,), im.size == (320, 320))
b = shelf.image(artist="Mother Mother")
check("artist photo via the old Lidarr path when the API path 404s", b is not None)
fetched.clear()
b = shelf.image(artist="Big Thief")
check("artist photo falls back to Lidarr's remote address", b is not None and fetched == ["https://x.dzcdn.net/bt.jpg"])
fetched.clear()
check("second ask comes from the NAS copy", shelf.image(artist="Big Thief") == b and fetched == [])
b = shelf.image(album="31")
check("album with no Lidarr cover falls back to the Cover Art Archive", b is not None and "coverartarchive.org/release-group/11111111-2222-3333-4444-000000000031" in fetched[-1])
check("Elliott Smith photo from Deezer", shelf.image(artist="Elliott Smith") is not None and fetched[-1].endswith("es/500.jpg"))
fetched.clear()
check("Deezer's blank photo is not used", shelf.image(artist="New Band") is None and fetched == [])
check("a miss is remembered", shelf.image(artist="New Band") is None)
check("bad release-group id refused", shelf.image(rg="../../etc") is None)
check("nothing asked, nothing given", shelf.image() is None)

# --- the lists the TV gets
with open(discover.FILE, "w") as fh:
    json.dump({"built": int(time.time()), "user": "u", "freshBuilt": 1,
               "loved": [{"name": "Mother Mother", "plays": 900}, {"name": "Elliott Smith", "plays": 800}, {"name": "Big Thief", "plays": 700}, {"name": "Never Looked Up", "plays": 5}],
               "recs": [{"name": "New Band", "because": "Big Thief"}, {"name": "Elliott Smith", "because": "x"}, {"name": "Mother Mother", "because": "x"}],
               "plays": {"big thief": 700, "antonio vivaldi": 3},
               "fresh": [{"title": "Fresh EP", "artist": "Big Thief", "date": NEWISH, "kind": "ep", "rgid": "r1", "why": "yours"},
                         {"title": "Brand New", "artist": "New Band", "date": NEWISH, "kind": "album", "rgid": "r2", "why": "recommended"}]}, fh)
discover.fill = lambda: None
shelf.invalidate(); shelf.library(wait=True)      # forget the requests made above
g = discover.get()
check("loved: Mother Mother and Elliott Smith (complete) are gone: %r" % [x["name"] for x in g["loved"]], [x["name"] for x in g["loved"]] == ["Big Thief", "Never Looked Up"])
check("loved rows say how many to get", g["loved"][0]["togo"] == 3 and g["loved"][0]["albums"] == 6 and g["loved"][0]["lid"] == 3 and g["loved"][1]["togo"] == -1)
check("recommended leaves out artists already on the shelf: %r" % [x["name"] for x in g["recs"]], [x["name"] for x in g["recs"]] == ["New Band"] and g["recs"][0]["togo"] == 2)
check("missing: one row per artist, most played first: %r" % [(m["name"], m["togo"]) for m in g["missing"]], [(m["name"], m["togo"]) for m in g["missing"]] == [("Big Thief", 3), ("Antonio Vivaldi", 40)])
check("new: Lidarr's and MusicBrainz's merged without doubles: %r" % [(n["title"], n["state"]) for n in g["releases"]], sorted((n["title"], n["state"]) for n in g["releases"]) == [("Brand New", "ext"), ("Fresh EP", "miss"), ("Next One", "soon")])
check("filling flag on while an artist is still unknown", g["filling"] is True)
discover.hide("antonio vivaldi")
g = discover.get()
check("hide removes the artist everywhere", [m["name"] for m in g["missing"]] == ["Big Thief"] and g["hidden"] == ["antonio vivaldi"])
discover.unhide("Antonio Vivaldi")
check("unhide brings them back", len(discover.get()["missing"]) == 2)
json.dumps(g)

# --- Lidarr refusing the all-albums call
H.all_fails = True
shelf.invalidate()
lib = shelf.library(wait=True)
check("falls back to asking artist by artist", sum(len(v) for v in lib["albums"].values()) == len(ALBUMS))

# --- every local module the server imports is copied into the container
src = open("server.py").read() + open("discover.py").read() + open("shelf.py").read()
copied = open("Dockerfile").read()
import re
mods = {m for m in re.findall(r"^\s*import (\w+)", src, re.M) if os.path.exists(m + ".py")}
check("Dockerfile copies %s" % sorted(mods), all(m + ".py" in copied for m in mods))
txt = shelf.selftest_text()
check("self-check prints a line per source", txt.count("\n") == 8)
print(txt)
print("FAILED %d" % check.bad if check.bad else "all passed")
sys.exit(1 if check.bad else 0)
