#!/bin/sh
# Runs ON the NAS as root:  ssh -t Elina@192.168.254.41 "curl -sL <this file> -o /tmp/plexfix.sh && sudo sh /tmp/plexfix.sh"
# Finds the Plex sign-in token (or asks for one), saves it for the Hearth helper, and checks it works.
# Prints no secrets.
DOCKER=/usr/local/bin/docker
echo "== 1. What the helper says now"
curl -s --max-time 6 -w "\n   HTTP %{http_code}\n" http://127.0.0.1:8765/px/plex/identity | cut -c1-200

echo "== 2. Looking for the Plex token"
TOK="$1"   # a token given on the command line skips the search
PREFS="/volume1/PlexMediaServer/AppData/Plex Media Server/Preferences.xml"
if [ -z "$TOK" ]; then
  if [ -f "$PREFS" ]; then
    TOK=$(grep -o 'PlexOnlineToken="[^"]*' "$PREFS" | sed 's/.*"//')
    echo "   read $PREFS (token $([ -n "$TOK" ] && echo found || echo MISSING))"
  else
    echo "   no file at $PREFS"
  fi
fi
if [ -z "$TOK" ]; then
  echo "   The NAS has no Plex token to read. Paste one."
  echo "   (Plex web: open a movie > ... > Get Info > View XML; copy the X-Plex-Token=... value from the address bar.)"
  printf "   Plex token: "
  read -r TOK < /dev/tty
fi
[ -z "$TOK" ] && { echo "No token, nothing changed."; exit 1; }

echo "== 3. Saving it for the helper"
$DOCKER exec -e T="$TOK" hearth-remote python3 -c '
import json, os
p = "/data/hearth-keys.json"
try:
    d = json.load(open(p))
except Exception:
    d = {}
t = os.environ["T"]
d.update(plexServer="http://192.168.254.41:32400", plexToken=t, plexServerToken=t)
json.dump(d, open(p, "w"))
os.chmod(p, 0o600)
print("   saved; keys now stored:", ", ".join(sorted(k for k in d if not k.endswith("Url") and k != "plexServer")))
' || { echo "   could not save (is the hearth-remote container running?)"; exit 1; }

echo "== 4. Checking (the helper re-reads keys every 20 s)"
sleep 22
curl -s --max-time 10 -o /dev/null -w "   Plex through the helper: HTTP %{http_code}  (200 means it works)\n" http://127.0.0.1:8765/px/plex/library/sections
