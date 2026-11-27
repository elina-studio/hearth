"""Your Ambiance clips, straight from the folder on the NAS.

Plex decides on its own when (and whether) a new file in the hearth folder joins its library; fireflies.mp4
and embers.mp4 sat in the folder for days without ever reaching the TV. So the helper reads the folder
itself. Every video file in it is a clip. One the TV can't play as it is (not H.264, or bigger than
1080p) gets a 720p H.264 copy, made once and kept in DATA_DIR/amb-clips. Each clip also gets a picture
taken from the video itself, so the preview on the TV is the clip, not a drawing.

Routes (server.py):
  GET /api/clips              {"folder", "clips": [{id, file, name, state, ready, pct, url, thumb, width, height}]}
  GET /api/clips?text=1       the same as plain lines, for the Mac command
  GET /api/clips/v/<id>.mp4   the clip (pieces on request)
  GET /api/clips/t/<id>.jpg   its picture
"""
import hashlib
import json
import os
import subprocess
import threading
import time

import mix

DATA_DIR = os.environ.get("DATA_DIR", "/data")
PUBLIC_URL = os.environ.get("PUBLIC_URL", "http://192.168.254.41:8765").rstrip("/")
FOLDERS = [d for d in os.environ.get("CLIPS_DIRS", "/volume1/plex/hearth:/volume1/plex/plex/hearth:/volume1/plex/plex/movies/hearth").split(":") if d]
CACHE = os.path.join(DATA_DIR, "amb-clips")
VIDEO_EXT = (".mp4", ".mov", ".m4v", ".mkv", ".webm", ".avi")
# the built-in moods' own words: their clips are made ready before the others
FIRST = ("firefl", "ember", "lightsout", "fire", "hearth", "campfire", "rain")

_lock = threading.Lock()
_clips = {}         # id -> {"id", "file", "src", "state", "pct", "why", "play", "width", "height"}
_wake = threading.Event()
_started = {"v": False}


def folders():
    """Every hearth folder that exists. The clips of all of them count; a file name in two folders is taken from the first."""
    return [d for d in FOLDERS if os.path.isdir(d)]


def folder():
    return ", ".join(folders())


def _id(path):
    st = os.stat(path)
    return hashlib.sha1(("%s|%d|%d" % (os.path.basename(path), st.st_size, int(st.st_mtime))).encode()).hexdigest()[:16]


def _rank(name):
    n = name.lower().replace(" ", "").replace("-", "").replace("_", "")
    for i, w in enumerate(FIRST):
        if n.startswith(w):
            return i
    return len(FIRST)


def scan():
    """Reads the folder: new files join the list (and the queue), files that left are forgotten."""
    d = folder()
    seen = {}
    taken = set()
    for one in folders():
        try:
            names = sorted(os.listdir(one))
        except OSError:
            names = []
        for n in names:
            # ._name files are the Mac's own notes about a file, not videos
            if n.startswith(".") or not n.lower().endswith(VIDEO_EXT) or n.lower() in taken:
                continue
            p = os.path.join(one, n)
            try:
                if not os.path.isfile(p) or os.path.getsize(p) < 1024:
                    continue
                seen[_id(p)] = p
                taken.add(n.lower())
            except OSError:
                continue
    added = False
    with _lock:
        for cid in list(_clips):
            if cid not in seen:
                del _clips[cid]
        for cid, p in seen.items():
            if cid not in _clips:
                _clips[cid] = {"id": cid, "file": os.path.basename(p), "src": p, "state": "waiting", "pct": 0, "why": "", "play": "", "width": 0, "height": 0}
                added = True
    if added:
        _wake.set()
    return d


def _thumb(c):
    out = os.path.join(CACHE, c["id"] + ".jpg")
    if os.path.isfile(out) and os.path.getsize(out) > 0:
        return
    # a frame a few seconds in (the first frame is often black); a very short clip falls back to its first frame
    for ss in ("4", "0"):
        try:
            subprocess.run([mix.FFMPEG, "-hide_banner", "-loglevel", "error", "-y", "-ss", ss, "-i", c["src"], "-frames:v", "1",
                            "-vf", "scale=-2:'min(720,ih)'", "-q:v", "4", out + ".tmp.jpg"], capture_output=True, timeout=120)
            if os.path.isfile(out + ".tmp.jpg") and os.path.getsize(out + ".tmp.jpg") > 0:
                os.replace(out + ".tmp.jpg", out)
                return
        except Exception as e:
            print("clips: no picture for", c["file"], e, flush=True)


def _plays_as_is(info):
    try:
        w, h = int(info.get("width") or 0), int(info.get("height") or 0)
    except (TypeError, ValueError):
        return False
    return info.get("codec_name") == "h264" and 0 < w <= 1920 and 0 < h <= 1080 and info.get("pix_fmt") in ("yuv420p", "yuvj420p")


def _convert(c, dest):
    total = mix._duration(c["src"]) or 0
    tmp = dest + ".part.mp4"
    cmd = [mix.FFMPEG, "-hide_banner", "-loglevel", "error", "-nostats", "-y", "-i", c["src"], "-map", "0:v:0", "-map", "0:a:0?",
           "-vf", "scale=-2:'min(720,ih)',format=yuv420p", "-fpsmax", "30", "-c:v", "libx264", "-preset", "veryfast", "-crf", "21", "-g", "60",
           "-c:a", "aac", "-b:a", "160k", "-ac", "2", "-movflags", "+faststart", "-progress", "pipe:1", tmp]
    err = open(os.path.join(CACHE, c["id"] + ".log"), "wb")
    p = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=err)
    for line in p.stdout:
        line = line.decode("utf-8", "replace").strip()
        if line.startswith("out_time_ms=") and total > 0:
            try:
                done = int(line.split("=", 1)[1]) / 1000000.0
                with _lock:
                    c["pct"] = max(0, min(99, int(done * 100 / total)))
            except ValueError:
                pass
    code = p.wait()
    err.close()
    if code != 0 or not os.path.isfile(tmp) or os.path.getsize(tmp) < 1024:
        why = ""
        try:
            with open(os.path.join(CACHE, c["id"] + ".log"), "rb") as fh:
                why = fh.read()[-300:].decode("utf-8", "replace").strip().replace("\n", " ")
        except OSError:
            pass
        raise RuntimeError(why or "ffmpeg stopped with code %d" % code)
    os.replace(tmp, dest)


def _prepare(c):
    os.makedirs(CACHE, exist_ok=True)
    _thumb(c)
    dest = os.path.join(CACHE, c["id"] + ".mp4")
    if os.path.isfile(dest):
        info = mix._probe(dest)
        play = dest
    else:
        info = mix._probe(c["src"])
        if not info.get("codec_name"):
            raise RuntimeError("not a video ffmpeg can read")
        if _plays_as_is(info):
            play = c["src"]
        else:
            with _lock:
                c["state"] = "converting"
            print("clips: converting", c["file"], info.get("codec_name"), info.get("width"), "x", info.get("height"), flush=True)
            _convert(c, dest)
            info = mix._probe(dest)
            play = dest
    with _lock:
        c["play"] = play
        c["width"] = int(info.get("width") or 0)
        c["height"] = int(info.get("height") or 0)
        c["pct"] = 100
        c["state"] = "ready"
    print("clips: ready", c["file"], "->", play, flush=True)


def _sweep():
    """Copies and pictures of files that left the folder are deleted."""
    try:
        with _lock:
            keep = set(_clips)
        for n in os.listdir(CACHE):
            if n.split(".")[0] not in keep:
                os.remove(os.path.join(CACHE, n))
    except OSError:
        pass


def worker():
    while True:
        scan()
        while True:
            with _lock:
                todo = [c for c in _clips.values() if c["state"] == "waiting"]
            if not todo:
                break
            todo.sort(key=lambda c: (_rank(c["file"]), c["file"].lower()))
            c = todo[0]
            try:
                _prepare(c)
            except Exception as e:
                with _lock:
                    c["state"] = "failed"
                    c["why"] = str(e)[:300]
                print("clips: failed", c["file"], e, flush=True)
        if folder():
            _sweep()
        _wake.clear()
        # look at the folder again every two minutes, or as soon as someone asks for the list
        _wake.wait(120)


def start():
    if _started["v"]:
        return
    _started["v"] = True
    threading.Thread(target=worker, daemon=True).start()


def listing():
    d = scan()
    with _lock:
        rows = [dict(c) for c in _clips.values()]
    rows.sort(key=lambda c: c["file"].lower())
    out = []
    for c in rows:
        name = os.path.splitext(c["file"])[0]
        out.append({"id": c["id"], "file": c["file"], "name": name, "state": c["state"], "ready": c["state"] == "ready", "pct": c["pct"],
                    "why": c["why"], "width": c["width"], "height": c["height"], "converted": bool(c["play"]) and c["play"] != c["src"],
                    "url": PUBLIC_URL + "/api/clips/v/" + c["id"] + ".mp4",
                    "thumb": (PUBLIC_URL + "/api/clips/t/" + c["id"] + ".jpg") if os.path.isfile(os.path.join(CACHE, c["id"] + ".jpg")) else ""})
    return {"folder": d, "clips": out}


def text():
    """Plain lines for the Mac command. The first line is DONE, WORKING or NOFOLDER."""
    li = listing()
    if not li["folder"]:
        return "NOFOLDER\nNo hearth folder found (looked for: %s)\n" % ", ".join(FOLDERS)
    busy = [c for c in li["clips"] if c["state"] in ("waiting", "converting")]
    lines = ["WORKING" if busy else "DONE", "Found in %s: %d clips" % (li["folder"], len(li["clips"]))]
    for c in li["clips"]:
        if c["state"] == "ready":
            how = "ready for the TV" + (" (made a TV copy)" if c["converted"] else " (plays as it is)")
        elif c["state"] == "converting":
            how = "making a TV copy, %d%%" % c["pct"]
        elif c["state"] == "waiting":
            how = "waiting its turn"
        else:
            how = "FAILED: " + c["why"]
        lines.append("  %-34s %s" % (c["file"], how))
    return "\n".join(lines) + "\n"


def play_path(cid):
    """The file the TV plays for a clip id, or None."""
    with _lock:
        c = _clips.get(cid)
        if c and c["state"] == "ready" and c["play"] and os.path.isfile(c["play"]):
            return c["play"]
    return None


def serve(h, path, q):
    if path == "/api/clips":
        if (q.get("text") or [""])[0]:
            body = text().encode()
            h.send_response(200)
            h.send_header("Content-Type", "text/plain; charset=utf-8")
            h.send_header("Cache-Control", "no-store")
            h.send_header("Content-Length", str(len(body)))
            h.end_headers()
            if h.command != "HEAD":
                h.wfile.write(body)
            return
        return h.send_json(listing())
    name = path.rsplit("/", 1)[-1]
    cid = name.split(".")[0]
    # an id is 16 hex digits: nothing else reaches the disk
    if len(cid) != 16 or any(ch not in "0123456789abcdef" for ch in cid):
        return h.send_json({"error": "not found"}, 404)
    if path.startswith("/api/clips/v/"):
        p = play_path(cid)
        if not p:
            return h.send_json({"error": "clip not ready"}, 404)
        return mix.send_file(h, p, "video/mp4")
    if path.startswith("/api/clips/t/"):
        p = os.path.join(CACHE, cid + ".jpg")
        if not os.path.isfile(p):
            return h.send_json({"error": "no picture"}, 404)
        return mix.send_file(h, p, "image/jpeg")
    h.send_json({"error": "not found"}, 404)
