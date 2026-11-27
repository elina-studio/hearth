#!/usr/bin/env python3
"""Hearth phone remote.

A tiny web server for the NAS. The phone opens the page, the page calls this
server, and this server talks to the Roku over ECP (port 8060) and to the
Wyoming whisper server for voice. Standard library only.

Settings (environment):
  TV_IP          Roku address              (default 192.168.254.9)
  HTTP_PORT      plain page, no mic        (default 8765)
  HTTPS_PORT     page with the mic button  (default 8766, 0 turns it off)
  WHISPER_HOST   Wyoming whisper host      (default 127.0.0.1)
  WHISPER_PORT   Wyoming whisper port      (default 10300)
  WHISPER_LANG   spoken language           (default en)
  DATA_DIR       where the HTTPS cert, lyrics cache and Last.fm session live (default /data)
  LASTFM_API_KEY / LASTFM_API_SECRET / PUBLIC_URL   Last.fm scrobbling (lastfm.py)
  HELPER_TOKEN   the house key (default: made on first start in DATA_DIR/helper-token); see guard.py
  MUSIC_ROOT     folder .lrc lyrics files may be read from (default /volume1, mounted read-only)
"""
import json
import os
import socket
import ssl
import subprocess
import sys
import traceback
import threading
import urllib.parse
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

import guard
import lastfm
import discover
import shelf
import lyrics
import web
import mix
import clips
import ratings

TV_IP = os.environ.get("TV_IP", "192.168.254.9")
HTTP_PORT = int(os.environ.get("HTTP_PORT", "8765"))
HTTPS_PORT = int(os.environ.get("HTTPS_PORT", "8766"))
WHISPER_HOST = os.environ.get("WHISPER_HOST", "127.0.0.1")
WHISPER_PORT = int(os.environ.get("WHISPER_PORT", "10300"))
WHISPER_LANG = os.environ.get("WHISPER_LANG", "en")
DATA_DIR = os.environ.get("DATA_DIR", "/data")
HERE = os.path.dirname(os.path.abspath(__file__))

# Keys the page may send. Anything else is refused.
KEYS = {
    "Home", "Rev", "Fwd", "Play", "Select", "Left", "Right", "Down", "Up", "Back",
    "InstantReplay", "Info", "Backspace", "Search", "Enter",
    "VolumeDown", "VolumeUp", "VolumeMute", "PowerOff", "PowerOn",
}

class TooBig(Exception):
    pass


class _NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *a, **k):
        return None


_no_redirect = urllib.request.build_opener(_NoRedirect)

ecp_lock = threading.Lock()  # one ECP call at a time keeps keys in order


def ecp(method, path, timeout=4):
    url = "http://%s:8060%s" % (TV_IP, path)
    req = urllib.request.Request(url, data=b"" if method == "POST" else None, method=method)
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return r.status, r.read()


def ecp_post(path):
    with ecp_lock:
        return ecp("POST", path)[0]


def lit(ch):
    return "/keypress/Lit_" + urllib.parse.quote(ch, safe="")


# ---------------------------------------------------------------- voice

def wy_send(sock, etype, data=None, payload=b""):
    head = {"type": etype}
    if data is not None:
        head["data"] = data
    if payload:
        head["payload_length"] = len(payload)
    sock.sendall(json.dumps(head).encode() + b"\n" + payload)


def wy_read(f):
    line = f.readline()
    if not line:
        return None
    ev = json.loads(line)
    data = ev.get("data") or {}
    if ev.get("data_length"):
        data.update(json.loads(f.read(ev["data_length"])))
    if ev.get("payload_length"):
        f.read(ev["payload_length"])
    ev["data"] = data
    return ev


def transcribe(pcm):
    """pcm: 16 kHz, 16-bit, mono little-endian samples."""
    fmt = {"rate": 16000, "width": 2, "channels": 1}
    with socket.create_connection((WHISPER_HOST, WHISPER_PORT), timeout=60) as s:
        wy_send(s, "transcribe", {"language": WHISPER_LANG})
        wy_send(s, "audio-start", fmt)
        step = 32000  # one second per chunk
        for i in range(0, len(pcm), step):
            wy_send(s, "audio-chunk", fmt, pcm[i:i + step])
        wy_send(s, "audio-stop", {})
        f = s.makefile("rb")
        while True:
            ev = wy_read(f)
            if ev is None:
                raise RuntimeError("whisper closed the connection")
            if ev["type"] == "transcript":
                return (ev["data"].get("text") or "").strip()


# ---------------------------------------------------------------- web

class Handler(BaseHTTPRequestHandler):
    server_version = "HearthRemote/1"

    def log_message(self, fmt, *args):
        pass  # quiet; errors still print below

    _ct = ""

    def send_header(self, k, v):
        if k.lower() == "content-type":
            self._ct = v
        super().send_header(k, v)

    def end_headers(self):
        for k, v in guard.SEC_HEADERS:
            super().send_header(k, v)
        if self._ct.startswith("text/html"):
            super().send_header("Content-Security-Policy", guard.CSP)
        super().end_headers()

    def gate(self, path):
        """True when the caller may go on. Otherwise the answer is already sent."""
        q = urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query)
        who = guard.check(self.client_address[0], path, self.headers, (q.get("t") or [""])[0])
        if who in ("open", "tv", "token"):
            return True
        if who == "query":
            if self.command == "GET" and not path.startswith(("/api/", "/px/")):
                # keep the key in a cookie, then drop it from the address bar
                rest = urllib.parse.urlencode([(k, v) for k, vs in q.items() if k != "t" for v in vs])
                self.send_response(302)
                secure = "; Secure" if self.server.is_https else ""
                self.send_header("Set-Cookie", "%s=%s; Path=/; Max-Age=31536000; HttpOnly; SameSite=Lax%s" % (guard.COOKIE, guard.TOKEN, secure))
                self.send_header("Location", path + ("?" + rest if rest else ""))
                self.send_header("Cache-Control", "no-store")
                self.send_header("Content-Length", "0")
                self.end_headers()
                return False
            return True
        print("denied %s %s %s" % (who, self.client_address[0], path[:80]), flush=True)
        if who == "locked":
            self.send_json({"error": "too many tries, wait a minute"}, 429)
        elif path.startswith(("/api/", "/px/")):
            self.send_json({"error": "locked: open the helper with the house key first"}, 401)
        else:
            sent = (q.get("t") or [""])[0]
            cookie = guard._cookie(self.headers.get("Cookie"))
            if sent:
                why = "The key in this link doesn't match the helper's key (%d characters; it should be 48). Print a fresh link with show-link.sh." % len(sent)
            elif cookie:
                why = "Your browser sent a key, but it is an old one. Open a fresh link with ?t=..."
            else:
                why = "No key arrived. If you just opened a link, your browser may be blocking cookies for this address."
            self.send_html("<!doctype html><meta name=viewport content='width=device-width'><body style='font:18px Georgia,serif;background:#0b100c;color:#e6dfc8;padding:32px'>"
                           "<h2>Hearth</h2><p>This page needs the house key. Open the link that ends in <code>?t=...</code> "
                           "(show-link.sh prints it).</p><p>%s</p><p style='opacity:.6;font-size:15px'>This device's address: %s</p>" % (why, self.client_address[0]), 401)
        return False

    def send_json(self, obj, code=200):
        body = json.dumps(obj).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def send_html(self, text, code=200):
        body = text.encode()
        self.send_response(code)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def qr(self):
        """A QR code of the phone page, for the TV's connect screen (needs the qrcode package; the page address is also shown as text)."""
        try:
            import io
            import qrcode
            img = qrcode.make(lastfm.PUBLIC_URL + "/lastfm", box_size=8, border=2)
            buf = io.BytesIO()
            img.save(buf, "PNG")
            body = buf.getvalue()
        except Exception:
            return self.send_json({"error": "no qr"}, 404)
        self.send_response(200)
        self.send_header("Content-Type", "image/png")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def body(self, limit=262144):
        n = int(self.headers.get("Content-Length") or 0)
        if n > limit or n < 0:
            raise TooBig()
        return self.rfile.read(n) if n else b""

    def do_HEAD(self):
        path = self.path.split("?")[0]
        if not self.gate(path):
            return
        if path.startswith("/px/"):
            return web.proxy(self, "HEAD", path)
        if path.startswith("/api/mix/s/"):
            return mix.serve_segment(self, path)
        if path == "/api/clips" or path.startswith("/api/clips/"):
            return clips.serve(self, path, urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query))
        if path == "/api/viz/loopfile":
            return mix.loop_play(self, urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query))
        self.send_json({"error": "not found"}, 404)

    def do_GET(self):
        path = self.path.split("?")[0]
        if not self.gate(path):
            return
        if path.startswith("/px/"):
            return web.proxy(self, "GET", path)
        if path == "/hearth" or path.startswith("/hearth/"):
            if path == "/hearth":
                self.send_response(302)
                self.send_header("Location", "/hearth/")
                self.end_headers()
                return
            web.serve_static(self, path)
            return
        if path in ("/", "/index.html"):
            with open(os.path.join(HERE, "index.html"), "rb") as fh:
                page = fh.read()
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Cache-Control", "no-store")
            self.send_header("Content-Length", str(len(page)))
            self.end_headers()
            self.wfile.write(page)
        elif path == "/api/pj/poll":
            q = urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query)
            try:
                since = int((q.get("since") or ["-1"])[0])
            except ValueError:
                since = -1
            self.send_json(web.pj_poll(since))
        elif path == "/api/status":
            self.status()
        elif path.startswith("/api/mix/s/"):
            mix.serve_segment(self, path)
        elif path == "/api/clips" or path.startswith("/api/clips/"):
            clips.serve(self, path, urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query))
        elif path == "/api/mix/start":
            mix.start(self, urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query))
        elif path == "/api/viz/audio":
            mix.audio(self, urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query))
        elif path == "/api/viz/sample":
            mix.sample(self)
        elif path == "/api/viz/loops":
            mix.loops_list(self)
        elif path == "/api/viz/loopfile":
            mix.loop_play(self, urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query))
        elif path == "/api/viz/status":
            mix.status(self)
        elif path == "/api/viz/renderer":
            mix.renderer(self)
        elif path == "/api/round":
            self.round_image()
        elif path == "/api/keys":
            # Hearth restores its saved keys from here after a reinstall (file written by tools/remote/save-keys.sh)
            try:
                with open(os.path.join(DATA_DIR, "hearth-keys.json")) as fh:
                    self.send_json(json.load(fh))
            except (OSError, ValueError):
                self.send_json({})
        elif path == "/api/lyrics":
            q = urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query)
            g = lambda k: (q.get(k) or [""])[0]
            try:
                dur = float(g("duration") or 0)
            except ValueError:
                dur = 0
            self.send_json(lyrics.find(g("artist"), g("title"), g("album"), dur, g("file")))
        elif path == "/api/discover":
            q = urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query)
            self.send_json(discover.get(bool((q.get("refresh") or [""])[0])))
        elif path == "/api/discover/img":
            q = urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query)
            one = lambda k: (q.get(k) or [""])[0]
            body = shelf.image(artist=one("artist"), album=one("album"), url=one("u"), rg=one("rg"))
            if body is None:
                return self.send_json({"error": "no picture"}, 404)
            self.send_response(200)
            self.send_header("Content-Type", "image/jpeg")
            self.send_header("Cache-Control", "max-age=604800")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
        elif path == "/api/discover/albums":
            q = urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query)
            self.send_json(shelf.albums((q.get("artist") or [""])[0]))
        elif path in ("/api/discover/selftest", "/api/ratings/selftest"):
            body = (ratings.selftest() if path == "/api/ratings/selftest" else shelf.selftest_text()).encode()
            self.send_response(200)
            self.send_header("Content-Type", "text/plain; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
        elif path == "/api/lastfm/status":
            self.send_json(lastfm.status())
        elif path in ("/lastfm", "/lastfm/done"):
            q = urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query)
            page = lastfm.done_page((q.get("token") or [""])[0]) if path == "/lastfm/done" else lastfm.phone_page()
            self.send_html(page)
        elif path == "/lastfm/qr.png":
            self.qr()
        else:
            self.send_json({"error": "not found"}, 404)

    def round_url_ok(self, url):
        # only http pictures from the Plex server this NAS already talks to (stops the helper being used to poke other devices)
        u = urllib.parse.urlsplit(url)
        if u.scheme != "http" or not u.hostname:
            return False
        allowed = {urllib.parse.urlsplit(web.keys().get("plexServer") or "http://192.168.254.41:32400").hostname, "192.168.254.41"}
        return u.hostname in allowed

    def round_image(self):
        # a picture cut to a circle with real transparency (Roku can't clip): ?u=<image url>&s=<size>
        q = urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query)
        url = (q.get("u") or [""])[0]
        try:
            size = max(32, min(600, int((q.get("s") or ["200"])[0])))
        except ValueError:
            size = 200
        if not self.round_url_ok(url):
            self.send_json({"error": "bad url"}, 400)
            return
        import hashlib
        cdir = os.path.join(DATA_DIR, "round")
        os.makedirs(cdir, exist_ok=True)
        f = os.path.join(cdir, hashlib.sha1((url + str(size)).encode()).hexdigest() + ".png")
        if not os.path.exists(f):
            try:
                from PIL import Image, ImageDraw
                import io
                raw = _no_redirect.open(url, timeout=10).read(12 * 1024 * 1024)
                im = Image.open(io.BytesIO(raw)).convert("RGBA")
                w, h = im.size
                side = min(w, h)
                im = im.crop(((w - side) // 2, (h - side) // 2, (w + side) // 2, (h + side) // 2)).resize((size, size), Image.LANCZOS)
                big = Image.new("L", (size * 4, size * 4), 0)
                ImageDraw.Draw(big).ellipse((0, 0, size * 4 - 1, size * 4 - 1), fill=255)
                im.putalpha(big.resize((size, size), Image.LANCZOS))
                im.save(f, "PNG")
            except Exception as e:
                print("round image error:", e, flush=True)
                self.send_json({"error": "could not make the picture"}, 502)
                return
        with open(f, "rb") as fh:
            body = fh.read()
        self.send_response(200)
        self.send_header("Content-Type", "image/png")
        self.send_header("Cache-Control", "max-age=86400")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def status(self):
        out = {"tv": False, "app": "", "hearth": False, "httpsPort": HTTPS_PORT, "projector": web.pj_online()}
        try:
            _, xml = ecp("GET", "/query/active-app", timeout=2)
            out["tv"] = True
            text = xml.decode("utf-8", "replace")
            import re
            m = re.search(r"<app[^>]*id=\"([^\"]*)\"[^>]*>([^<]*)</app>", text)
            if m:
                out["app"] = m.group(2).strip()
                out["hearth"] = m.group(1) == "dev"
            else:
                out["app"] = "Home screen"
        except Exception:
            pass
        self.send_json(out)

    def do_DELETE(self):
        path = self.path.split("?")[0]
        if not self.gate(path):
            return
        if path.startswith("/px/"):
            return web.proxy(self, "DELETE", path)
        self.send_json({"error": "not found"}, 404)

    def do_POST(self):
        path = self.path.split("?")[0]
        if not self.gate(path):
            return
        if path.startswith("/px/"):
            return web.proxy(self, "POST", path)
        try:
            if path == "/api/voice":
                pcm = self.body(8 * 1024 * 1024)
                if len(pcm) < 3200:
                    return self.send_json({"text": ""})
                return self.send_json({"text": transcribe(pcm)})
            if path == "/api/viz/loop":
                return mix.loop_upload(self, urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query))
            req = json.loads(self.body() or b"{}")
            if path == "/api/viz/hello":
                mix.hello(self.client_address[0], req)
                # the renderer compares this with its own files and updates itself when they differ
                return self.send_json({"ok": True, "renderer": mix.renderer_version()})
            if path == "/api/lastfm/begin":
                return self.send_json(lastfm.begin())
            if path == "/api/lastfm/event":
                return self.send_json(lastfm.event(req))
            if path == "/api/ratings":
                # the Requests room's IMDb and Rotten Tomatoes scores (ratings.py)
                return self.send_json(ratings.get(req.get("ids") or []))
            if path == "/api/discover/hide":
                return self.send_json(discover.hide(str(req.get("name", ""))))
            if path == "/api/discover/unhide":
                return self.send_json(discover.unhide(str(req.get("name", ""))))
            if path == "/api/discover/request":
                if req.get("artist"):
                    return self.send_json(shelf.request_missing(str(req["artist"])))
                return self.send_json(shelf.request_album(req.get("albumId") or req.get("albumid") or 0))
            if path == "/api/lastfm/disconnect":
                lastfm.disconnect()
                return self.send_json({"ok": True})
            if req.get("to") == "projector" and path in ("/api/key", "/api/text"):
                # the phone is driving the projector page instead of the Roku
                if path == "/api/key":
                    if req.get("key", "") not in KEYS:
                        return self.send_json({"error": "unknown key"}, 400)
                    web.pj_push({"key": req["key"]})
                else:
                    web.pj_push({"text": req.get("text", "")[:200], "go": req.get("go", "")})
                return self.send_json({"ok": True, "online": web.pj_online()})
            if path == "/api/key":
                key = req.get("key", "")
                if key not in KEYS:
                    return self.send_json({"error": "unknown key"}, 400)
                ecp_post("/keypress/" + key)
            elif path == "/api/text":
                # Hearth's own hook: lands in the focused Hearth keyboard
                q = {"hearthText": req.get("text", "")[:200]}
                if req.get("go") in ("search", "request"):
                    q["hearthGo"] = req["go"]
                ecp_post("/input?" + urllib.parse.urlencode(q, quote_via=urllib.parse.quote))
            elif path == "/api/type":
                # Any app's Roku keyboard: delete some letters, then type some
                for _ in range(min(int(req.get("back", 0)), 200)):
                    ecp_post("/keypress/Backspace")
                for ch in req.get("add", "")[:200]:
                    ecp_post(lit(ch))
            elif path == "/api/cast":
                # seconds to move the TV's music by (from the phone's microphone), signed
                d = max(-6.0, min(6.0, float(req.get("delta", 0))))
                ecp_post("/input?castTrim=" + ("%.3f" % d))
            elif path == "/api/launch":
                ecp_post("/launch/dev")
            else:
                return self.send_json({"error": "not found"}, 404)
            self.send_json({"ok": True})
        except TooBig:
            self.send_json({"error": "too big"}, 413)
        except (OSError, urllib.error.URLError) as e:
            print("upstream error:", path, e, flush=True)
            self.send_json({"error": "Can't reach %s" % (path.startswith("/api/voice") and "whisper" or "the TV")}, 502)
        except Exception:
            traceback.print_exc()
            self.send_json({"error": "something went wrong"}, 500)


def make_cert():
    crt = os.path.join(DATA_DIR, "remote.crt")
    key = os.path.join(DATA_DIR, "remote.key")
    if not (os.path.exists(crt) and os.path.exists(key)):
        os.makedirs(DATA_DIR, exist_ok=True)
        san = os.environ.get("CERT_SAN", "IP:192.168.254.41,DNS:localhost")
        subprocess.run([
            "openssl", "req", "-x509", "-newkey", "rsa:2048", "-nodes", "-days", "3650",
            "-keyout", key, "-out", crt, "-subj", "/CN=Hearth Remote",
            "-addext", "subjectAltName=" + san,
        ], check=True, capture_output=True)
    return crt, key


def main():
    servers = [ThreadingHTTPServer(("0.0.0.0", HTTP_PORT), Handler)]
    servers[0].is_https = False
    if HTTPS_PORT:
        try:
            crt, key = make_cert()
            s = ThreadingHTTPServer(("0.0.0.0", HTTPS_PORT), Handler)
            s.is_https = True
            ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
            ctx.minimum_version = ssl.TLSVersion.TLSv1_2
            ctx.load_cert_chain(crt, key)
            s.socket = ctx.wrap_socket(s.socket, server_side=True)
            servers.append(s)
        except Exception as e:
            print("HTTPS off (mic button won't work):", e, flush=True)
    for s in servers[1:]:
        threading.Thread(target=s.serve_forever, daemon=True).start()
    print("Hearth remote: http :%d%s, TV %s, whisper %s:%d" % (
        HTTP_PORT, (", https :%d" % HTTPS_PORT) if len(servers) > 1 else "", TV_IP, WHISPER_HOST, WHISPER_PORT), flush=True)
    print("House key in %s (the TV %s is let in without it; phones open /?t=<key> once)" % (os.path.join(DATA_DIR, "helper-token"), TV_IP), flush=True)
    mix.set_token(guard.TOKEN)
    clips.start()
    threading.Thread(target=lastfm.worker, daemon=True).start()
    threading.Thread(target=discover.worker, daemon=True).start()
    threading.Thread(target=ratings.worker, daemon=True).start()
    servers[0].serve_forever()


if __name__ == "__main__":
    main()
