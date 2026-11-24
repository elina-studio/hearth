"""Who may talk to the Hearth helper.

One long random "house key" (never in git) protects everything except what the TV itself needs
and the Last.fm pairing pages:
  - the TV (by its address, TV_IP) may use /api/* and /lastfm/qr.png without the key, so it can
    restore its saved keys after a reinstall, ask for lyrics, round pictures and scrobble;
  - the projector (PROJECTOR_IP) may use its own page (/hearth, /px, /api/pj) the same way;
  - a phone or the projector page opens the helper once with  http://<nas>:8765/?t=<house key>
    and the helper keeps it in a cookie (HttpOnly, SameSite=Strict) from then on;
  - scripts send it as the header  X-Hearth-Token.
Too many wrong tries from one address are locked out for a minute.
The key lives in DATA_DIR/helper-token (made on first start, mode 600) or the HELPER_TOKEN setting.
"""
import hmac
import os
import secrets
import threading
import time

DATA_DIR = os.environ.get("DATA_DIR", "/data")
TV_IP = os.environ.get("TV_IP", "192.168.254.9")
PROJECTOR_IP = os.environ.get("PROJECTOR_IP", "").strip()
COOKIE = "hearth_t"

# pages that stay open: Last.fm pairing (Last.fm itself checks the token it hands back)
OPEN_PATHS = ("/lastfm", "/lastfm/done")
# what the TV (and only the TV's address) may call without the key
TV_PREFIXES = ("/api/",)
TV_PATHS = ("/lastfm/qr.png",)
# the projector's browser can't type a long key, so its address may open its own page and what that page reads
PROJECTOR_PREFIXES = ("/hearth", "/px/", "/api/pj/")

SEC_HEADERS = (
    ("X-Content-Type-Options", "nosniff"),
    ("X-Frame-Options", "DENY"),
    ("Referrer-Policy", "no-referrer"),
    ("Cross-Origin-Resource-Policy", "same-origin"),
    ("Permissions-Policy", "camera=(), geolocation=(), payment=()"),
)
# the pages use inline script/style; everything else must come from the helper itself
# (the phone page also uses Google Fonts, the projector page TMDB pictures)
CSP = ("default-src 'self'; script-src 'self' 'unsafe-inline'; "
       "style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; "
       "font-src 'self' data: https://fonts.gstatic.com; img-src 'self' data: blob: https://image.tmdb.org; "
       "media-src 'self' blob:; connect-src 'self'; worker-src 'self' blob:; "
       "frame-ancestors 'none'; base-uri 'none'; form-action 'self'")

_fails = {}
_lock = threading.Lock()
LIMIT, WINDOW = 10, 60


def load_token():
    t = os.environ.get("HELPER_TOKEN", "").strip()
    if t:
        return t
    p = os.path.join(DATA_DIR, "helper-token")
    try:
        with open(p) as fh:
            t = fh.read().strip()
        if len(t) >= 16:
            return t
    except OSError:
        pass
    t = secrets.token_hex(24)
    os.makedirs(DATA_DIR, exist_ok=True)
    fd = os.open(p, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w") as fh:
        fh.write(t)
    return t


TOKEN = load_token()


def _cookie(header):
    for part in (header or "").split(";"):
        k, _, v = part.strip().partition("=")
        if k == COOKIE:
            return v
    return ""


def locked_out(ip):
    now = time.time()
    with _lock:
        n, t0 = _fails.get(ip, (0, now))
        if now - t0 > WINDOW:
            _fails.pop(ip, None)
            return False
        return n >= LIMIT


def _fail(ip):
    now = time.time()
    with _lock:
        n, t0 = _fails.get(ip, (0, now))
        if now - t0 > WINDOW:
            n, t0 = 0, now
        _fails[ip] = (n + 1, t0)


def ok(candidate):
    return bool(candidate) and hmac.compare_digest(candidate.encode(), TOKEN.encode())


def check(ip, path, headers, query_t):
    """Returns 'open', 'tv', 'token' (valid), 'query' (valid ?t=), 'locked' or 'denied'."""
    if path in OPEN_PATHS:
        return "open"
    if ip == TV_IP and (path.startswith(TV_PREFIXES) or path in TV_PATHS):
        return "tv"
    if PROJECTOR_IP and ip == PROJECTOR_IP and path.startswith(PROJECTOR_PREFIXES):
        return "tv"
    if locked_out(ip):
        return "locked"
    if ok(headers.get("X-Hearth-Token", "")) or ok(_cookie(headers.get("Cookie"))):
        return "token"
    if ok(query_t):
        return "query"
    _fail(ip)
    return "denied"
