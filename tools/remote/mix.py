"""Music with pictures, as one stream the TV can play.

The TV plays one stream at a time, so a song can't play under a separate video. This module joins them:
  fire  your Ambiance fire clip, looped, with the song (Hearth music view)
  viz   MilkDrop for this song: rendered live on the NucBox when it is on (it follows the beat),
        otherwise a ready-made loop of the same look with the song

Every answer is an HLS address the TV's Video node plays; video position 0 is the song at `ss`.

Routes (server.py):
  GET  /api/mix/start?kind=fire|viz&file=<song path>&ss=<s>&clip=<plex part key>&look=<n>&prefetch=1
  GET  /api/mix/s/<id>/<index.m3u8|sNNNN.ts>   the stream
  POST /api/viz/hello                           the NucBox says it's on (every minute)
  GET  /api/viz/audio?file=                     the NucBox reads the song from here
  GET  /api/viz/sample                          a song for making the loops
  GET  /api/viz/loops                           which loops are on the NAS
  POST /api/viz/loop?n=                         the NucBox uploads a loop
  GET  /api/viz/loopfile?n=                     a loop on its own (while the song plays on speakers)
  GET  /api/viz/status                          for the setup script
"""
import hashlib
import http.client
import json
import os
import random
import re
import shutil
import subprocess
import threading
import time
import urllib.parse
import urllib.request

import web

DATA_DIR = os.environ.get("DATA_DIR", "/data")
PUBLIC_URL = os.environ.get("PUBLIC_URL", "http://192.168.254.41:8765").rstrip("/")
ROOTS = [r for r in os.environ.get("MIX_ROOTS", "/volume1/music:/volume1/plex/plex/music").split(":") if r]
WORK = os.environ.get("MIX_WORK", "/tmp/hearth-mix")
LOOPS = os.path.join(DATA_DIR, "viz-loops")
FIRES = os.path.join(DATA_DIR, "fire-clips")
FFMPEG = os.environ.get("FFMPEG", "ffmpeg")
FFPROBE = os.environ.get("FFPROBE", "ffprobe")
KEEP = 6
AUDIO_EXT = (".mp3", ".flac", ".m4a", ".aac", ".ogg", ".opus", ".wav", ".alac", ".wma", ".aiff", ".aif")

_lock = threading.Lock()
_sessions = {}      # id -> {"dir", "proc", "used"}
_nucbox = {}        # {"host", "port", "seen", ...}
_fire_jobs = {}     # cache path -> "working" | "failed: why"
_token = {"v": ""}


def set_token(tok):
    _token["v"] = tok or ""


# ---------------------------------------------------------------- files

def song_path(p):
    """The real path of a song under the music folders, or None."""
    if not p:
        return None
    real = os.path.realpath(p)
    for r in ROOTS:
        rr = os.path.realpath(r)
        if real.startswith(rr + os.sep) and os.path.isfile(real):
            return real
    return None


def send_file(h, full, ctype):
    """Range-aware file answer (the TV's player asks for pieces of an mp4)."""
    size = os.path.getsize(full)
    start, end = 0, size - 1
    rng = h.headers.get("Range") or ""
    m = re.match(r"bytes=(\d*)-(\d*)$", rng.strip())
    if m and (m.group(1) or m.group(2)):
        if m.group(1):
            start = int(m.group(1))
            if m.group(2):
                end = min(int(m.group(2)), size - 1)
        else:
            start = max(0, size - int(m.group(2)))
        if start > end:
            h.send_response(416)
            h.send_header("Content-Range", "bytes */%d" % size)
            h.send_header("Content-Length", "0")
            h.end_headers()
            return
        h.send_response(206)
        h.send_header("Content-Range", "bytes %d-%d/%d" % (start, end, size))
    else:
        h.send_response(200)
    h.send_header("Content-Type", ctype)
    h.send_header("Accept-Ranges", "bytes")
    h.send_header("Content-Length", str(end - start + 1))
    h.send_header("Cache-Control", "no-store")
    h.end_headers()
    if h.command == "HEAD":
        return
    try:
        with open(full, "rb") as fh:
            fh.seek(start)
            left = end - start + 1
            while left > 0:
                chunk = fh.read(min(65536, left))
                if not chunk:
                    break
                h.wfile.write(chunk)
                left -= len(chunk)
    except (BrokenPipeError, ConnectionResetError):
        pass  # the player hung up (it seeks by asking for another piece): nothing to do


# ---------------------------------------------------------------- HLS sessions on the NAS

def _sid(*parts):
    return hashlib.sha1("|".join(str(p) for p in parts).encode()).hexdigest()[:16]


def _duration(path):
    try:
        out = subprocess.run([FFPROBE, "-v", "error", "-show_entries", "format=duration", "-of", "default=nw=1:nk=1", path],
                             capture_output=True, timeout=30).stdout
        return float(out.strip() or 0) or 3600.0
    except Exception:
        return 3600.0


def _segments(d):
    try:
        with open(os.path.join(d, "index.m3u8")) as fh:
            return fh.read().count(".ts")
    except OSError:
        return 0


def _prune():
    old = sorted(_sessions.items(), key=lambda kv: kv[1]["used"], reverse=True)[KEEP:]
    for sid, s in old:
        if s["proc"].poll() is None:
            s["proc"].kill()
        shutil.rmtree(s["dir"], ignore_errors=True)
        _sessions.pop(sid, None)


def loop_session(video, song, ss):
    """Starts (or reuses) ffmpeg joining a looping video with the song from ss. Returns (id, error)."""
    sid = _sid(video, os.path.getmtime(video), song, round(ss))
    with _lock:
        s = _sessions.get(sid)
        if s and (s["proc"].poll() in (None, 0)) and os.path.isdir(s["dir"]):
            s["used"] = time.time()
        else:
            d = os.path.join(WORK, sid)
            shutil.rmtree(d, ignore_errors=True)
            os.makedirs(d, exist_ok=True)
            cmd = [FFMPEG, "-hide_banner", "-loglevel", "error", "-y",
                   "-stream_loop", "-1", "-i", video]
            if ss > 0:
                cmd += ["-ss", "%.2f" % ss]
            # -shortest alone never ends a copied, endlessly looped picture: stop at the song's own length
            left = max(1.0, _duration(song) - ss)
            cmd += ["-i", song, "-t", "%.2f" % left, "-map", "0:v:0", "-map", "1:a:0", "-c:v", "copy",
                    "-c:a", "aac", "-b:a", "192k", "-ac", "2", "-ar", "44100", "-shortest",
                    "-f", "hls", "-hls_time", "4", "-hls_list_size", "0", "-hls_playlist_type", "event",
                    "-hls_segment_filename", os.path.join(d, "s%04d.ts"), os.path.join(d, "index.m3u8")]
            err = open(os.path.join(d, "ffmpeg.log"), "wb")
            s = {"dir": d, "proc": subprocess.Popen(cmd, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=err), "used": time.time()}
            _sessions[sid] = s
            _prune()
    # copying the picture is quick: the first pieces are there within a second or two
    until = time.time() + 15
    while time.time() < until:
        if _segments(s["dir"]) >= 2 or (s["proc"].poll() == 0 and _segments(s["dir"]) >= 1):
            return sid, None
        if s["proc"].poll() not in (None, 0):
            try:
                with open(os.path.join(s["dir"], "ffmpeg.log"), "rb") as fh:
                    why = fh.read()[-300:].decode("utf-8", "replace").strip()
            except OSError:
                why = ""
            return None, "ffmpeg stopped: " + (why or "no reason given")
        time.sleep(0.15)
    return None, "the stream didn't start in time"


def serve_segment(h, path):
    m = re.match(r"^/api/mix/s/([0-9a-f]{16})/(index\.m3u8|s\d{4}\.ts)$", path)
    if not m:
        return h.send_json({"error": "not found"}, 404)
    with _lock:
        s = _sessions.get(m.group(1))
        if s:
            s["used"] = time.time()
    full = os.path.join(WORK, m.group(1), m.group(2))
    if not s or not os.path.isfile(full):
        return h.send_json({"error": "gone"}, 404)
    ctype = "application/vnd.apple.mpegurl" if full.endswith(".m3u8") else "video/mp2t"
    send_file(h, full, ctype)


# ---------------------------------------------------------------- fire clip (from Plex, kept on the NAS)

def _probe(path):
    try:
        out = subprocess.run([FFPROBE, "-v", "error", "-select_streams", "v:0", "-show_entries", "stream=codec_name,width,height,pix_fmt",
                              "-of", "json", path], capture_output=True, timeout=30).stdout
        st = json.loads(out or b"{}").get("streams") or [{}]
        return st[0]
    except Exception:
        return {}


def _fetch_fire(part_key, dest):
    try:
        base, token, _ = web._target("plex")
        if not token:
            raise RuntimeError("no Plex key on the helper (run sync-keys.sh)")
        url = base + part_key + ("&" if "?" in part_key else "?") + "X-Plex-Token=" + urllib.parse.quote(token)
        tmp = dest + ".part"
        with urllib.request.urlopen(url, timeout=60) as r, open(tmp, "wb") as fh:
            shutil.copyfileobj(r, fh, 1 << 20)
        info = _probe(tmp)
        ok = info.get("codec_name") == "h264" and int(info.get("width") or 9999) <= 1920 and info.get("pix_fmt") in ("yuv420p", "yuvj420p", None)
        if ok:
            os.replace(tmp, dest)
        else:
            # the TV only decodes plain h264 up to 1080p: convert once, keep the copy
            subprocess.run([FFMPEG, "-hide_banner", "-loglevel", "error", "-y", "-i", tmp, "-an", "-vf", "scale=-2:'min(1080,ih)',format=yuv420p",
                            "-c:v", "libx264", "-preset", "veryfast", "-crf", "20", "-g", "60", "-movflags", "+faststart", dest + ".conv.mp4"], check=True, timeout=3600)
            os.replace(dest + ".conv.mp4", dest)
            os.remove(tmp)
        with _lock:
            _fire_jobs.pop(dest, None)
        print("mix: fire clip ready", dest, flush=True)
    except Exception as e:
        with _lock:
            _fire_jobs[dest] = "failed: %s" % e
        print("mix: fire clip failed:", e, flush=True)


def fire_clip(part_key):
    """(path, None) when the clip is on the NAS; (None, 'preparing') while it is being fetched; (None, why) on failure."""
    if not part_key or not part_key.startswith("/library/parts/"):
        return None, "no fire clip given"
    os.makedirs(FIRES, exist_ok=True)
    dest = os.path.join(FIRES, _sid(part_key) + ".mp4")
    if os.path.isfile(dest):
        return dest, None
    with _lock:
        st = _fire_jobs.get(dest)
        if st == "working":
            return None, "preparing"
        if st and st.startswith("failed") and not st.endswith("retry"):
            _fire_jobs[dest] = st + " retry"
            return None, st
        _fire_jobs[dest] = "working"
    threading.Thread(target=_fetch_fire, args=(part_key, dest), daemon=True).start()
    return None, "preparing"


# ---------------------------------------------------------------- the NucBox

def hello(ip, body):
    with _lock:
        _nucbox.clear()
        _nucbox.update({"host": ip, "port": int(body.get("port") or 8790), "seen": time.time(),
                        "width": body.get("width"), "fps": body.get("measuredFps")})


def nucbox():
    """The NucBox when it said hello in the last few minutes and renders fast enough to keep up with a song."""
    with _lock:
        if _nucbox and time.time() - _nucbox["seen"] < 150:
            fps = _nucbox.get("fps") or 0
            if fps and fps < 33:
                return None  # too slow: the song would stall, so the ready-made loops play instead
            return dict(_nucbox)
    return None


def _nucbox_render(nb, song, look, ss, prefetch):
    audio = PUBLIC_URL + "/api/viz/audio?" + urllib.parse.urlencode({"file": song, "t": _token["v"]})
    body = json.dumps({"audioUrl": audio, "look": look, "ss": ss, "prefetch": bool(prefetch)}).encode()
    c = http.client.HTTPConnection(nb["host"], nb["port"], timeout=16)
    try:
        c.request("POST", "/render", body, {"Content-Type": "application/json", "X-Hearth-Token": _token["v"]})
        r = c.getresponse()
        data = json.loads(r.read() or b"{}")
        if r.status == 200 and data.get("path"):
            return "http://%s:%d%s" % (nb["host"], nb["port"], data["path"]), None
        return None, data.get("error") or ("renderer said %d" % r.status)
    except Exception as e:
        return None, str(e)
    finally:
        c.close()


def loop_file(look):
    try:
        n = int(look)
    except (TypeError, ValueError):
        return None
    p = os.path.join(LOOPS, "%d.mp4" % n)
    return p if os.path.isfile(p) else None


# ---------------------------------------------------------------- routes

def start(h, q):
    g = lambda k: (q.get(k) or [""])[0]
    kind = g("kind")
    song = song_path(g("file"))
    try:
        ss = max(0.0, float(g("ss") or 0))
    except ValueError:
        ss = 0.0
    if not song:
        return h.send_json({"ok": False, "why": "song not found on the NAS"}, 404)
    if kind == "fire":
        clip, why = fire_clip(g("clip"))
        if not clip:
            return h.send_json({"ok": False, "why": why}, 202 if why == "preparing" else 404)
        sid, why = loop_session(clip, song, ss)
        if not sid:
            return h.send_json({"ok": False, "why": why}, 500)
        return h.send_json({"ok": True, "url": PUBLIC_URL + "/api/mix/s/%s/index.m3u8" % sid, "kind": "fire"})
    if kind == "viz":
        look = g("look") or "57"
        prefetch = g("prefetch") == "1"
        nb = nucbox()
        why = "the NucBox renderer is off"
        if nb:
            if prefetch:
                threading.Thread(target=_nucbox_render, args=(nb, song, look, ss, True), daemon=True).start()
                return h.send_json({"ok": True, "kind": "prefetch"})
            url, why = _nucbox_render(nb, song, look, ss, False)
            if url:
                return h.send_json({"ok": True, "url": url, "kind": "live", "look": look})
            print("mix: NucBox render failed:", why, flush=True)
        if prefetch:
            return h.send_json({"ok": True, "kind": "none"})
        lf = loop_file(look)
        if not lf:
            return h.send_json({"ok": False, "why": why + " and there's no ready-made loop for this look yet"}, 404)
        sid, why2 = loop_session(lf, song, ss)
        if not sid:
            return h.send_json({"ok": False, "why": why2}, 500)
        return h.send_json({"ok": True, "url": PUBLIC_URL + "/api/mix/s/%s/index.m3u8" % sid, "kind": "loop", "look": look})
    return h.send_json({"ok": False, "why": "kind must be fire or viz"}, 400)


def audio(h, q):
    song = song_path((q.get("file") or [""])[0])
    if not song:
        return h.send_json({"error": "not found"}, 404)
    send_file(h, song, "application/octet-stream")


def sample(h):
    """A random song, for making the loops move to real music."""
    found = []
    for r in ROOTS:
        for dp, dn, fn in os.walk(r):
            for f in fn:
                if f.lower().endswith(AUDIO_EXT):
                    found.append(os.path.join(dp, f))
            if len(found) > 3000:
                break
    if not found:
        return h.send_json({"error": "no songs"}, 404)
    send_file(h, random.choice(found), "application/octet-stream")


def loops_list(h):
    have = []
    if os.path.isdir(LOOPS):
        for f in os.listdir(LOOPS):
            m = re.match(r"^(\d+)\.mp4$", f)
            if m:
                have.append(int(m.group(1)))
    h.send_json({"looks": sorted(have)})


def loop_upload(h, q):
    try:
        n = int((q.get("n") or [""])[0])
    except ValueError:
        return h.send_json({"error": "bad look"}, 400)
    size = int(h.headers.get("Content-Length") or 0)
    if size <= 0 or size > 80 * 1024 * 1024:
        return h.send_json({"error": "bad size"}, 413)
    os.makedirs(LOOPS, exist_ok=True)
    tmp = os.path.join(LOOPS, "%d.mp4.part" % n)
    left = size
    with open(tmp, "wb") as fh:
        while left > 0:
            chunk = h.rfile.read(min(1 << 20, left))
            if not chunk:
                break
            fh.write(chunk)
            left -= len(chunk)
    if left:
        os.remove(tmp)
        return h.send_json({"error": "upload cut short"}, 400)
    if _probe(tmp).get("codec_name") != "h264":
        os.remove(tmp)
        return h.send_json({"error": "not an h264 video"}, 400)
    os.replace(tmp, os.path.join(LOOPS, "%d.mp4" % n))
    h.send_json({"ok": True})


def loop_play(h, q):
    lf = loop_file((q.get("n") or [""])[0])
    if not lf:
        return h.send_json({"error": "no loop"}, 404)
    send_file(h, lf, "video/mp4")


def status(h):
    with _lock:
        nb = dict(_nucbox) if _nucbox and time.time() - _nucbox["seen"] < 150 else None
    have = []
    if os.path.isdir(LOOPS):
        have = [f for f in os.listdir(LOOPS) if f.endswith(".mp4")]
    ff = shutil.which(FFMPEG) is not None
    h.send_json({"ffmpeg": ff, "nucbox": ({"host": nb["host"], "port": nb["port"], "secondsAgo": int(time.time() - nb["seen"]),
                                           "fps": nb.get("fps")} if nb else None), "loops": len(have)})
