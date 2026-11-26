#!/bin/bash
# Pair Last.fm with the NAS helper and build the Discover lists, checking each step. One ssh, one sudo password.
#   bash <(curl -sL https://raw.githubusercontent.com/elina-studio/hearth/<commit>/tools/remote/pair-lastfm.sh)
# While it waits, open http://192.168.254.41:8765/lastfm on any computer or phone at home and allow Hearth.
# The house key is read on the NAS and never printed.
NAS="Elina@192.168.254.41"
# read, not $(cat <<EOF): the bash on a Mac (3.2) can't parse some script text inside $( )
IFS= read -r -d '' REMOTE <<'EOF'
U=http://127.0.0.1:8765
H="X-Hearth-Token: $(cat /volume1/docker/hearth-remote/data/helper-token 2>/dev/null)"
get() { curl -s -m 15 -H "$H" "$U$1"; }
field() { printf '%s' "$1" | grep -o "\"$2\": *[^,}]*" | head -1 | sed 's/^[^:]*: *//; s/"//g'; }
st=$(get /api/lastfm/status)
[ -z "$st" ] && { echo "The helper isn't answering on the NAS. Is the hearth-remote container running?"; exit 1; }
[ "$(field "$st" configured)" = "true" ] || { echo "The Last.fm key and secret are missing from /volume1/docker/hearth-remote/.env"; exit 1; }
if [ "$(field "$st" state)" = "connected" ] && [ -n "$(field "$st" user)" ]; then
  echo "Last.fm is already paired as $(field "$st" user)."
else
  r=$(curl -s -m 15 -X POST -H "$H" -H "Content-Type: application/json" -d '{}' "$U/api/lastfm/begin")
  [ "$(field "$r" ok)" = "true" ] || { echo "Last.fm wouldn't start pairing: $(field "$r" error)"; exit 1; }
  echo
  echo "  Now, on your PC or phone, open:  http://192.168.254.41:8765/lastfm"
  echo "  Check the code says $(field "$r" code), press the Sign in button, then allow access on Last.fm."
  echo
  echo "Waiting for Last.fm (up to 9 minutes)..."
  i=0
  while [ $i -lt 180 ]; do
    sleep 3; i=$((i + 1))
    st=$(get /api/lastfm/status)
    [ "$(field "$st" state)" = "connected" ] && break
  done
  [ "$(field "$st" state)" = "connected" ] || { echo "Still not paired after 9 minutes. If the page said 'That didn't work', send me that line."; exit 1; }
  echo "Paired as $(field "$st" user)."
fi
echo "Building your Discover lists from Last.fm..."
get "/api/discover?refresh=1" >/dev/null
i=0
while [ $i -lt 60 ]; do
  sleep 5; i=$((i + 1))
  d=$(get /api/discover)
  b=$(field "$d" built); e=$(field "$d" error)
  if [ -n "$b" ] && [ "$b" != "0" ]; then
    echo "Done: $(printf '%s' "$d" | grep -o '"because"' | wc -l | tr -d ' ') recommended artists ready. Open Music > Discover."
    echo "New releases keep filling in for about 6 more minutes (MusicBrainz is slow on purpose)."
    exit 0
  fi
  [ -n "$e" ] && [ "$(field "$d" building)" = "false" ] && { echo "The NAS couldn't build the lists: $e"; exit 1; }
done
echo "The lists still aren't built after 5 minutes. Send me the output of this command."
EOF
B=$(printf '%s' "$REMOTE" | base64 | tr -d '\n')
ssh -t "$NAS" "echo $B | base64 -d > /tmp/hearth-pair.sh && sudo sh /tmp/hearth-pair.sh; rm -f /tmp/hearth-pair.sh"
