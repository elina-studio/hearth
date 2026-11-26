#!/bin/bash
# One command that puts EVERY key back, on the TV and in the NAS helper's saved copy (so every launch can restore them).
#   bash <(curl -sL https://raw.githubusercontent.com/elina-studio/hearth/<commit>/tools/remote/sync-keys.sh)
# It reads each key from its own app on the NAS (Sonarr, Radarr, Lidarr, Overseerr, Bazarr, Plex), rewrites
# /volume1/docker/hearth-remote/data/hearth-keys.json with all of them (keeping the Home Assistant details saved there by ha-weather.sh, and sending them to the TV too),
# and sends them to the TV. One ssh, one sudo password. No key is ever printed.
NAS="Elina@192.168.254.41"
REMOTE=$(cat <<'EOF'
D=/volume1/docker
TV=192.168.254.9
J=$D/hearth-remote/data/hearth-keys.json
for a in sonarr radarr lidarr; do
  f=$(ls "$D/$a/config/config.xml" "$D/$a/config.xml" 2>/dev/null | head -1)
  v=""; [ -n "$f" ] && v=$(grep -o '<ApiKey>[^<]*' "$f" | head -1 | sed 's/<ApiKey>//')
  eval "K_$a=\$v"
done
f=$(find "$D" -maxdepth 6 -name settings.json 2>/dev/null | grep -i seerr | head -1)
K_overseerr=""; [ -n "$f" ] && K_overseerr=$(grep -o '"apiKey": *"[^"]*' "$f" | head -1 | sed 's/.*"//')
f=$(find "$D/bazarr" -maxdepth 4 \( -name config.yaml -o -name config.ini \) 2>/dev/null | head -1)
K_bazarr=""; [ -n "$f" ] && K_bazarr=$(grep -i -m1 apikey "$f" | sed "s/.*[:=] *//; s/[\"' ]//g")
p="/volume1/PlexMediaServer/AppData/Plex Media Server/Preferences.xml"
K_plex=""; [ -f "$p" ] && K_plex=$(grep -o 'PlexOnlineToken="[^"]*' "$p" | sed 's/.*"//')
old() { grep -oE "\"$1\": *\"[^\"]*\"" "$J" 2>/dev/null | head -1 | sed -E 's/.*: *"(.*)"/\1/'; }
# a key this run can't find keeps whatever the NAS copy already had
[ -z "$K_plex" ] && K_plex=$(old plexToken)
for n in overseerr lidarr bazarr radarr sonarr; do
  eval "[ -z \"\$K_$n\" ] && K_$n=\$(old ${n}Key)"
done
OUT="{"
add() { [ -n "$2" ] && OUT="$OUT\"$1\":\"$2\","; }
add plexToken "$K_plex"; add plexServerToken "$K_plex"
add plexServer "$(old plexServer)"; [ -z "$(old plexServer)" ] && add plexServer "http://192.168.254.41:32400"
add plexServerName "$(old plexServerName)"
add overseerrUrl "http://192.168.254.41:5055"; add overseerrKey "$K_overseerr"
add lidarrUrl "http://192.168.254.41:8686";    add lidarrKey "$K_lidarr"
add bazarrUrl "http://192.168.254.41:6767";    add bazarrKey "$K_bazarr"
add radarrUrl "http://192.168.254.41:7878";    add radarrKey "$K_radarr"
add sonarrUrl "http://192.168.254.41:8989";    add sonarrKey "$K_sonarr"
add haUrl "$(old haUrl)"; add haToken "$(old haToken)"; add haEntity "$(old haEntity)"
OUT="${OUT%,}}"
for n in plex overseerr lidarr bazarr radarr sonarr; do
  eval "v=\$K_$n"; [ -n "$v" ] && echo "  found $n" || echo "  MISSING $n (not changed)"
done
[ -n "$(old haToken)" ] && echo "  kept Home Assistant" || echo "  Home Assistant token not saved (not changed)"
mkdir -p "$D/hearth-remote/data"
printf '%s' "$OUT" > "$J" && chmod 600 "$J" && echo "saved on the NAS helper"
[ -n "$K_overseerr" ] && curl -s -X POST -G --data-urlencode "overseerrUrl=http://192.168.254.41:5055" --data-urlencode "overseerrKey=$K_overseerr" "http://$TV:8060/input"
[ -n "$K_lidarr" ]    && curl -s -X POST -G --data-urlencode "lidarrUrl=http://192.168.254.41:8686" --data-urlencode "lidarrKey=$K_lidarr" "http://$TV:8060/input"
[ -n "$K_bazarr" ]    && curl -s -X POST -G --data-urlencode "bazarrUrl=http://192.168.254.41:6767" --data-urlencode "bazarrKey=$K_bazarr" "http://$TV:8060/input"
[ -n "$K_radarr" ]    && curl -s -X POST -G --data-urlencode "radarrUrl=http://192.168.254.41:7878" --data-urlencode "radarrKey=$K_radarr" "http://$TV:8060/input"
[ -n "$K_sonarr" ]    && curl -s -X POST -G --data-urlencode "sonarrUrl=http://192.168.254.41:8989" --data-urlencode "sonarrKey=$K_sonarr" "http://$TV:8060/input"
HT=$(old haToken)
[ -n "$HT" ] && curl -s -X POST -G --data-urlencode "haUrl=$(old haUrl)" --data-urlencode "haToken=$HT" --data-urlencode "haEntity=$(old haEntity)" "http://$TV:8060/input"
echo "sent to the TV (Hearth must be open for the TV to take them)"
EOF
)
B=$(printf '%s' "$REMOTE" | base64 | tr -d '\n')
ssh -t "$NAS" "echo $B | base64 -d > /tmp/hearth-sync.sh && sudo sh /tmp/hearth-sync.sh; rm -f /tmp/hearth-sync.sh"
