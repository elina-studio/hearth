#!/usr/bin/env python3
"""A pretend Roku running a tiny Hearth model, for testing tools/walk/walk.sh without the TV.
ECP on :18060, dev web on :18080 (screenshots, install), debug log on :18085.
It is not the app: it only prints HWALK lines shaped like the real trace, so the walk script's logic can be checked.
Usage: python3 tools/walk/fake_tv.py [--crash-at N] [--error-at N]"""
import socket, threading, sys, time, hashlib
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

ROOMS = ["HomeRoom", "LibraryRoom", "LibraryRoom", "MusicRoom", "RequestsRoom", "AmbianceRoom", "PhotosRoom", "SearchRoom"]
ZONES = {"LibraryRoom": ["buttons", "tabs", "chips", "grid"], "HomeRoom": ["hero", "tonight", "dash", "rows"],
         "RequestsRoom": ["bar", "rail", "grid"], "MusicRoom": ["panel", "tabs", "content"], "PhotosRoom": ["buttons", "albums"],
         "SearchRoom": ["kb", "results"], "AmbianceRoom": ["moods"], "DetailsScreen": ["bar", "act", "tabs", "eps"]}
args = sys.argv[1:]
CRASH_AT = int(args[args.index("--crash-at") + 1]) if "--crash-at" in args else -1
ERROR_AT = int(args[args.index("--error-at") + 1]) if "--error-at" in args else -1

class App:
    def __init__(self):
        self.lock = threading.Lock(); self.clients = []; self.running = False; self.presses = 0
        self.reset()
    def reset(self):
        self.stack = ["HubScreen"]; self.hubzone = "room"; self.pill = 0; self.room = 0; self.zi = 0; self.dialog = ""
        self.top_zi = 0; self.term = ""; self.last = ""
    def log(self, line):
        for c in list(self.clients):
            try: c.sendall((line + "\n").encode())
            except OSError: self.clients.remove(c)
    def sig(self):
        top = self.stack[-1]
        if self.dialog: chain = "Group#stack>HubScreen>StandardMessageDialog>"
        elif top == "HubScreen" and self.hubzone == "pills": chain = "Group#stack>HubScreen>Group#pills>Poster>"
        elif top == "HubScreen": chain = "Group#stack>HubScreen>Group#roomHolder>%s>" % ROOMS[self.room]
        else: chain = "Group#stack>%s>" % top
        return "stack=%s> focus=%s dialog=%s music=stopped" % (">".join(self.stack), chain, self.dialog)
    def tick(self):
        while True:
            time.sleep(0.4)
            with self.lock:
                if not self.running: continue
                s = self.sig()
                if s != self.last: self.last = s; self.log("HWALK " + s)
    def keyline(self, key, handled, screen, st):
        self.log("HWALK key=%s handled=%s screen=%s st=%s" % (key, "yes" if handled else "no", screen, st))
    def press(self, k):
        with self.lock:
            if not self.running: return
            self.presses += 1
            if self.presses == ERROR_AT:
                self.log("BRIGHTSCRIPT: ERROR: roSGNode.CallFunc: no such function: pkg:/components/Fake.brs(12)")
                self.log("Backtrace begin")
            if self.presses == CRASH_AT:
                self.running = False; self.log("------ app exited ------"); return
            key = {"Select": "OK", "Info": "options", "Rev": "rewind", "Fwd": "fastforward", "InstantReplay": "replay",
                   "Backspace": "backspace"}.get(k, k.lower() if not k.startswith("Lit_") else k)
            if self.dialog:
                if key == "back": self.dialog = ""
                elif key == "OK" and self.dialog.endswith("Leave Hearth?"): self.running = False
                return  # Roku dialogs do not pass keys to the app's handlers
            top = self.stack[-1]
            if top == "HubScreen" and self.hubzone == "pills":
                if key in ("left", "right"): self.pill = (self.pill + (1 if key == "right" else -1)) % 8
                elif key in ("down", "OK"): self.room = self.pill; self.hubzone = "room"; self.zi = 0
                elif key == "back":
                    if self.pill != 0 or self.room != 0: self.pill = 0; self.room = 0
                    else: self.dialog = "StandardMessageDialog:Leave Hearth?"
                elif key == "options": self.dialog = "StandardMessageDialog:Hearth"
                self.keyline(key, True, "HubScreen", "zone:pills pillIndex:%d current:x " % self.pill); return
            if top == "HubScreen":
                r = ROOMS[self.room]; zs = ZONES[r]
                if key == "back" or (key == "up" and self.zi == 0): self.hubzone = "pills"
                elif key == "down": self.zi = min(self.zi + 1, len(zs) - 1)
                elif key == "up": self.zi -= 1
                elif key.startswith("Lit_"): self.term += key[4:].lower()
                elif key == "backspace": self.term = self.term[:-1]
                elif key == "right" and r == "SearchRoom" and self.term: self.zi = 1
                elif key == "OK":
                    z = zs[self.zi]
                    if z in ("grid", "results", "hero"): self.stack.append("DetailsScreen"); self.top_zi = 1
                    elif r == "AmbianceRoom": self.stack.append("MoodScreen")
                    elif r == "PhotosRoom": self.stack.append("SlideshowScreen")
                    elif r == "RequestsRoom" and z == "grid": pass
                self.keyline(key, True, r, "zone:%s term:%s " % (zs[self.zi], self.term)); return
            # pushed screens: Back pops; Details has zones; OK on act starts the player
            if key == "back": self.stack.pop(); self.keyline(key, True, top, ""); return
            if top == "DetailsScreen":
                zs = ZONES["DetailsScreen"]
                if key == "down": self.top_zi = min(self.top_zi + 1, len(zs) - 1)
                elif key == "up": self.top_zi = max(self.top_zi - 1, 0)
                elif key == "OK" and zs[self.top_zi] == "act": self.stack.append("PlayerScreen")
                self.keyline(key, True, top, "zone:%s " % zs[self.top_zi]); return
            self.keyline(key, True, top, "zone:x ")
    def open(self, mode):
        with self.lock:
            names = {"radio": "RadioScreen", "lastfm": "LastfmScreen", "schedules": "ScheduleScreen", "big": "MusicBigView",
                     "cover": "MusicView", "milk": "MusicView", "hearth": "MusicView", "request": "LidarrScreen"}
            if mode in names: self.stack.append(names[mode]); self.log("HWALK open " + mode)
    def launch(self, walk):
        def boot():
            time.sleep(2)
            with self.lock:
                self.reset(); self.running = True
                if walk: self.log("HWALK trace on")
        threading.Thread(target=boot, daemon=True).start()

APP = App()

class ECP(BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def reply(self, body, code=200, ctype="text/xml"):
        b = body.encode() if isinstance(body, str) else body
        self.send_response(code); self.send_header("Content-Type", ctype); self.send_header("Content-Length", str(len(b))); self.end_headers(); self.wfile.write(b)
    def do_POST(self):
        n = int(self.headers.get("Content-Length") or 0)
        if n: self.rfile.read(n)
        p = self.path
        if p.startswith("/keypress/"):
            k = p[len("/keypress/"):]
            if k == "Home":
                with APP.lock: APP.running = False
            else: APP.press(k)
        elif p.startswith("/launch/dev"): APP.launch("walk=1" in p)
        elif p.startswith("/input"):
            if "walkOpen=" in p: APP.open(p.split("walkOpen=")[1].split("&")[0])
        self.reply("")
    def do_GET(self):
        if self.path.startswith("/query/active-app"):
            app = '<app id="dev" type="appl">Hearth</app>' if APP.running else '<app>Roku</app>'
            self.reply("<active-app>%s</active-app>" % app)
        elif self.path.startswith("/query/device-info"):
            self.reply("<device-info><model-name>Fake Roku</model-name></device-info>")
        else: self.reply("", 404)

class Web(BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def reply(self, body, code=200, ctype="text/html"):
        b = body.encode() if isinstance(body, str) else body
        self.send_response(code); self.send_header("Content-Type", ctype); self.send_header("Content-Length", str(len(b))); self.end_headers(); self.wfile.write(b)
    def do_GET(self):
        if self.path.startswith("/pkgs/dev.jpg"):
            with APP.lock: s = APP.sig() + str(APP.presses if APP.stack[-1] != "HubScreen" else "")
            self.reply(b"\xff\xd8FAKEJPEG" + hashlib.md5(s.encode()).digest(), ctype="image/jpeg")
        else: self.reply("<html>dev installer</html>")
    def do_POST(self):
        n = int(self.headers.get("Content-Length") or 0)
        body = self.rfile.read(n) if n else b""
        if self.path == "/plugin_inspect": self.reply('<img src="pkgs/dev.jpg?time=%d">' % time.time())
        elif self.path == "/plugin_install":
            APP.launch(False)
            self.reply("<font color=red>Install Success.</font>")
        else: self.reply("", 404)

def log_server():
    srv = socket.socket(); srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1); srv.bind(("127.0.0.1", 18085)); srv.listen(2)
    while True:
        c, _ = srv.accept(); APP.clients.append(c)

threading.Thread(target=log_server, daemon=True).start()
threading.Thread(target=APP.tick, daemon=True).start()
threading.Thread(target=lambda: ThreadingHTTPServer(("127.0.0.1", 18060), ECP).serve_forever(), daemon=True).start()
print("fake TV up", flush=True)
ThreadingHTTPServer(("127.0.0.1", 18080), Web).serve_forever()
