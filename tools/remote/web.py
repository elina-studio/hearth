"""Hearth for browsers (the projector).

Two jobs, both reached through the phone-remote helper so the page never holds a key:
  /hearth/...       the web app itself (static files in ./web)
  /px/<service>/... a pass-through to Plex or Overseerr with the saved key added on the way,
                    streaming and Range-aware so video and music can seek.

Keys come from DATA_DIR/hearth-keys.json (written by save-keys.sh). Standard library only.
"""
import http.client
import json
import mimetypes
import os
import time
import urllib.parse

HERE = os.path.dirname(os.path.abspath(__file__))
WEB = os.path.join(HERE, "web")
DATA_DIR = os.environ.get("DATA_DIR", "/data")

mimetypes.add_type("font/ttf", ".ttf")
mimetypes.add_type("audio/mpeg", ".mp3")

_keys = {"t": 0, "v": {}}


def keys():
    if time.time() - _keys["t"] > 20:
        try:
            with open(os.path.join(DATA_DIR, "hearth-keys.json")) as fh:
                _keys["v"] = json.load(fh)
        except (OSError, ValueError):
            _keys["v"] = {}
        _keys["t"] = time.time()
    return _keys["v"]


def serve_static(h, path):
    """GET /hearth/<file>. Returns True when it answered."""
    rel = path[len("/hearth"):].lstrip("/") or "index.html"
    full = os.path.normpath(os.path.join(WEB, rel))
    if not full.startswith(WEB + os.sep) or not os.path.isfile(full):
        h.send_json({"error": "not found"}, 404)
        return True
    ctype = mimetypes.guess_type(full)[0] or "application/octet-stream"
    if ctype.startswith("text/") or ctype in ("application/javascript",):
        ctype += "; charset=utf-8"
    size = os.path.getsize(full)
    h.send_response(200)
    h.send_header("Content-Type", ctype)
    h.send_header("Content-Length", str(size))
    # pages and code always fresh (so a redeploy shows up); pictures, fonts and sounds can be kept
    h.send_header("Cache-Control", "no-cache" if ctype.startswith(("text/", "application/javascript")) else "max-age=86400")
    h.end_headers()
    with open(full, "rb") as fh:
        while True:
            chunk = fh.read(65536)
            if not chunk:
                break
            h.wfile.write(chunk)
    return True


def _target(service):
    k = keys()
    if service == "plex":
        base = k.get("plexServer") or "http://192.168.254.41:32400"
        return base.rstrip("/"), k.get("plexServerToken") or k.get("plexToken") or "", "plex"
    if service == "overseerr":
        return (k.get("overseerrUrl") or "http://192.168.254.41:5055").rstrip("/"), k.get("overseerrKey") or "", "overseerr"
    return None, "", ""


def proxy(h, method, path):
    """/px/<service>/<rest>?query -> the service, with its key added."""
    parts = urllib.parse.urlsplit(h.path)
    segs = parts.path.split("/", 3)  # ['', 'px', 'plex', 'rest...']
    if len(segs) < 3:
        h.send_json({"error": "bad path"}, 400)
        return
    base, secret, kind = _target(segs[2])
    if not base:
        h.send_json({"error": "unknown service"}, 404)
        return
    if not secret:
        h.send_json({"error": "no key saved for %s (run save-keys.sh)" % segs[2]}, 503)
        return
    rest = "/" + (segs[3] if len(segs) > 3 else "")
    query = urllib.parse.parse_qsl(parts.query, keep_blank_values=True)
    headers = {"Accept": h.headers.get("Accept", "*/*")}
    if kind == "plex":
        query = [(k, v) for k, v in query if k != "X-Plex-Token"] + [("X-Plex-Token", secret)]
        headers["X-Plex-Client-Identifier"] = "hearth-projector"
        headers["X-Plex-Product"] = "Hearth"
        headers["X-Plex-Platform"] = "Chrome"
    else:
        headers["X-Api-Key"] = secret
    for name in ("Range", "Content-Type", "If-None-Match", "If-Modified-Since"):
        if h.headers.get(name):
            headers[name] = h.headers[name]
    body = None
    n = int(h.headers.get("Content-Length") or 0)
    if n:
        body = h.rfile.read(n)
    u = urllib.parse.urlsplit(base)
    try:
        conn = http.client.HTTPConnection(u.hostname, u.port or 80, timeout=60)
        conn.request(method, urllib.parse.quote(rest, safe="/:@!$&'()*+,;=-._~") + "?" + urllib.parse.urlencode(query), body=body, headers=headers)
        r = conn.getresponse()
    except Exception as e:
        h.send_json({"error": "can't reach %s: %s" % (segs[2], e)}, 502)
        return
    h.send_response(r.status)
    for name in ("Content-Type", "Content-Length", "Content-Range", "Accept-Ranges", "Cache-Control", "ETag", "Last-Modified"):
        v = r.getheader(name)
        if v:
            h.send_header(name, v)
    h.send_header("Access-Control-Allow-Origin", "*")
    h.end_headers()
    if method == "HEAD":
        conn.close()
        return
    try:
        while True:
            chunk = r.read(65536)
            if not chunk:
                break
            h.wfile.write(chunk)
    except (BrokenPipeError, ConnectionResetError):
        pass  # the player moved on (a seek); normal
    finally:
        conn.close()
