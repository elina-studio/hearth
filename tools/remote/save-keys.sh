#!/bin/bash
# Run on the Mac:  bash <(curl -sL https://raw.githubusercontent.com/elina-studio/hearth/claude/project-thread-3b4es1/tools/remote/save-keys.sh)
# 1. rebuilds the NAS helper (it now serves the saved keys at /api/keys)
# 2. reads each app's API key from its container's config on the NAS
# 3. saves them all in the helper's data folder (so Hearth restores them itself after any reinstall)
# 4. sends them to the TV right now over ECP and restarts Hearth
# Nothing is printed or written to git. Typed values (read -s) don't show on screen.
NAS="Elina@192.168.254.41"
TV="192.168.254.9"
CTL="-o ControlMaster=auto -o ControlPath=/tmp/hearth-ssh-%r-%h -o ControlPersist=300"
R() { ssh -t $CTL "$NAS" "$@"; }

echo "Signing in to the NAS (ssh password, then the sudo password)..."
R "sudo -v" || exit 1

echo "Updating the NAS helper..."
R "mkdir -p /volume1/docker/hearth-remote && rm -rf /tmp/hearth-dl && mkdir /tmp/hearth-dl && cd /tmp/hearth-dl && curl -sL https://github.com/elina-studio/hearth/archive/refs/heads/claude/project-thread-3b4es1.tar.gz | tar xz && cp hearth-*/tools/remote/* /volume1/docker/hearth-remote/ && cd /volume1/docker/hearth-remote && sudo /usr/local/bin/docker compose up -d --build >/dev/null 2>&1; echo helper updated"

echo "Reading keys from the NAS..."
R "cp /volume1/docker/hearth-remote/gather-keys.sh /tmp/hearth-gather.sh" >/dev/null
OUT=$(ssh -t $CTL "$NAS" "sudo sh /tmp/hearth-gather.sh; rm -f /tmp/hearth-gather.sh" 2>/dev/null | tr -d '\r')
get() { echo "$OUT" | grep "^$1=" | head -1 | cut -d= -f2-; }
SON=$(get sonarr); RAD=$(get radarr); LID=$(get lidarr); OVR=$(get overseerr); BAZ=$(get bazarr); PLX=$(get plex)
for n in sonarr radarr lidarr overseerr bazarr plex; do [ -n "$(get $n)" ] && echo "  found $n" || echo "  MISSING $n (you'll be asked below)"; done

ask() { # name var
  if [ -z "${!2}" ]; then read -r -s -p "Paste the $1 (hidden, Enter to skip): " v; echo; printf -v "$2" '%s' "$v"; fi
}
ask "Overseerr API key" OVR; ask "Radarr API key" RAD; ask "Sonarr API key" SON; ask "Lidarr API key" LID; ask "Bazarr API key" BAZ
read -r -s -p "Paste the Home Assistant long-lived token (hidden, Enter to skip): " HAT; echo
read -r -p "Home Assistant weather entity [weather.home]: " HAE; HAE=${HAE:-weather.home}

J="{"; add() { [ -n "$2" ] && J="$J\"$1\":\"$2\","; }
add plexToken "$PLX"; add plexServerToken "$PLX"; add plexServer "http://192.168.254.41:32400"
add overseerrUrl "http://192.168.254.41:5055"; add overseerrKey "$OVR"
add lidarrUrl "http://192.168.254.41:8686"; add lidarrKey "$LID"
add bazarrUrl "http://192.168.254.41:6767"; add bazarrKey "$BAZ"
add radarrUrl "http://192.168.254.41:7878"; add radarrKey "$RAD"
add sonarrUrl "http://192.168.254.41:8989"; add sonarrKey "$SON"
if [ -n "$HAT" ]; then add haUrl "http://192.168.254.41:8123"; add haToken "$HAT"; add haEntity "$HAE"; fi
J="${J%,}}"

echo "Saving a copy on the NAS helper..."
printf '%s' "$J" | ssh $CTL "$NAS" "sudo tee /volume1/docker/hearth-remote/data/hearth-keys.json >/dev/null && sudo chmod 600 /volume1/docker/hearth-remote/data/hearth-keys.json" && echo saved

echo "Sending to the TV..."
ARGS=(); for pair in overseerrUrl=http://192.168.254.41:5055 overseerrKey="$OVR" lidarrUrl=http://192.168.254.41:8686 lidarrKey="$LID" bazarrUrl=http://192.168.254.41:6767 bazarrKey="$BAZ" radarrUrl=http://192.168.254.41:7878 radarrKey="$RAD" sonarrUrl=http://192.168.254.41:8989 sonarrKey="$SON"; do
  k=${pair%%=*}; v=${pair#*=}; [ -n "$v" ] && ARGS+=(--data-urlencode "$k=$v")
done
if [ -n "$HAT" ]; then ARGS+=(--data-urlencode "haUrl=http://192.168.254.41:8123" --data-urlencode "haToken=$HAT" --data-urlencode "haEntity=$HAE"); fi
curl -s -X POST -G "${ARGS[@]}" "http://$TV:8060/input" && echo sent
sleep 1; curl -s -X POST "http://$TV:8060/keypress/Home"; sleep 2; curl -s -X POST "http://$TV:8060/launch/dev"
echo "Done. Hearth is restarting; Plex comes back on launch. If it still asks you to sign in, tell me."
