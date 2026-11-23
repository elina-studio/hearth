#!/bin/bash
# Run on the Mac:  bash <(curl -sL https://raw.githubusercontent.com/elina-studio/hearth/claude/project-thread-nqrlx1/tools/remote/fix-plex.sh)
# Finds the Plex token on the NAS (or asks you to paste it), saves it for the Hearth helper, and checks the result.
# Nothing secret is printed or written to git.
NAS="Elina@192.168.254.41"
BASE="http://192.168.254.41:8765"
RAW="https://raw.githubusercontent.com/elina-studio/hearth/claude/project-thread-nqrlx1/tools/remote/find-plex.sh"
CTL="-o ControlMaster=auto -o ControlPath=/tmp/hearth-ssh-%r-%h -o ControlPersist=120"

echo "What the helper says right now (no secrets):"
curl -s --max-time 6 -w "\n  -> HTTP %{http_code}\n" "$BASE/px/plex/identity" | cut -c1-200

echo "Signing in to the NAS (ssh password, then the sudo password)..."
ssh -t $CTL "$NAS" "sudo -v" || exit 1
OUT=$(ssh -t $CTL "$NAS" "curl -sL $RAW -o /tmp/find-plex.sh; sudo sh /tmp/find-plex.sh; rm -f /tmp/find-plex.sh" 2>/dev/null | tr -d '\r')
echo "$OUT" | grep -v '^plex='
TOK=$(echo "$OUT" | grep '^plex=' | head -1 | cut -d= -f2-)
if [ -z "$TOK" ]; then
  echo "The NAS has no Plex sign-in token to read. Paste one instead."
  echo "(Plex web: open any movie > ... > Get Info > View XML, and copy the X-Plex-Token=... value from the address bar.)"
  read -r -s -p "Plex token (hidden): " TOK; echo
fi
[ -z "$TOK" ] && { echo "No token, nothing changed."; exit 1; }

OLD=$(curl -s --max-time 4 "$BASE/api/keys"); OLD=${OLD:-\{\}}
for k in plexServer plexToken plexServerToken; do OLD=$(echo "$OLD" | sed -E "s/\"$k\": *\"[^\"]*\",? *//; s/,[[:space:]]*}/}/"); done
NEW="${OLD%\}}"; [ "$NEW" = "{" ] && SEP="" || SEP=","
NEW="$NEW$SEP\"plexServer\":\"http://192.168.254.41:32400\",\"plexToken\":\"$TOK\",\"plexServerToken\":\"$TOK\"}"
printf '%s' "$NEW" | ssh $CTL "$NAS" "sudo tee /volume1/docker/hearth-remote/data/hearth-keys.json >/dev/null && sudo chmod 600 /volume1/docker/hearth-remote/data/hearth-keys.json" && echo "saved on the NAS"

sleep 22   # the helper re-reads its keys every 20 seconds
echo "Plex through the helper now:"
curl -s --max-time 8 -o /dev/null -w "  -> HTTP %{http_code}  (200 = working)\n" "$BASE/px/plex/library/sections"
