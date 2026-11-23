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
  MUSIC_ROOT     folder .lrc lyrics files may be read from (default /volume1, mounted read-only)
"""
import json
import os
import socket
import ssl
import subprocess
import threading
import urllib.parse
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

import lastfm
import lyrics

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

    def send_json(self, obj, code=200):
        body = json.dumps(obj).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def send_html(self, text):
        body = text.encode()
        self.send_response(200)
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

    def body(self):
        n = int(self.headers.get("Content-Length") or 0)
        return self.rfile.read(n) if n else b""

    def do_GET(self):
        path = self.path.split("?")[0]
        if path in ("/", "/index.html"):
            with open(os.path.join(HERE, "index.html"), "rb") as fh:
                page = fh.read()
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Cache-Control", "no-store")
            self.send_header("Content-Length", str(len(page)))
            self.end_headers()
            self.wfile.write(page)
        elif path == "/api/status":
            self.status()
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

    def status(self):
        out = {"tv": False, "app": "", "hearth": False, "httpsPort": HTTPS_PORT}
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

    def do_POST(self):
        path = self.path.split("?")[0]
        try:
            if path == "/api/voice":
                pcm = self.body()
                if len(pcm) < 3200:
                    return self.send_json({"text": ""})
                return self.send_json({"text": transcribe(pcm)})
            req = json.loads(self.body() or b"{}")
            if path == "/api/lastfm/begin":
                return self.send_json(lastfm.begin())
            if path == "/api/lastfm/event":
                return self.send_json(lastfm.event(req))
            if path == "/api/lastfm/disconnect":
                lastfm.disconnect()
                return self.send_json({"ok": True})
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
            elif path == "/api/launch":
                ecp_post("/launch/dev")
            else:
                return self.send_json({"error": "not found"}, 404)
            self.send_json({"ok": True})
        except (OSError, urllib.error.URLError) as e:
            self.send_json({"error": "Can't reach %s: %s" % (path.startswith("/api/voice") and "whisper" or "the TV", e)}, 502)
        except Exception as e:
            self.send_json({"error": str(e)}, 500)


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
    if HTTPS_PORT:
        try:
            crt, key = make_cert()
            s = ThreadingHTTPServer(("0.0.0.0", HTTPS_PORT), Handler)
            ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
            ctx.load_cert_chain(crt, key)
            s.socket = ctx.wrap_socket(s.socket, server_side=True)
            servers.append(s)
        except Exception as e:
            print("HTTPS off (mic button won't work):", e, flush=True)
    for s in servers[1:]:
        threading.Thread(target=s.serve_forever, daemon=True).start()
    print("Hearth remote: http :%d%s, TV %s, whisper %s:%d" % (
        HTTP_PORT, (", https :%d" % HTTPS_PORT) if len(servers) > 1 else "", TV_IP, WHISPER_HOST, WHISPER_PORT), flush=True)
    threading.Thread(target=lastfm.worker, daemon=True).start()
    servers[0].serve_forever()


if __name__ == "__main__":
    main()
