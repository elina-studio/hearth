#!/bin/sh
# Runs on the NAS (as root, via save-keys.sh). Prints name=value for each key it can find.
D=${DOCKER_ROOT:-/volume1/docker}
for a in sonarr radarr lidarr; do
  f=$(ls "$D/$a/config/config.xml" "$D/$a/config.xml" 2>/dev/null | head -1)
  [ -n "$f" ] && echo "$a=$(grep -o '<ApiKey>[^<]*' "$f" | head -1 | sed 's/<ApiKey>//')"
done
f=$(find "$D" -maxdepth 5 -name settings.json -path '*seerr*' 2>/dev/null | head -1)
[ -n "$f" ] && echo "overseerr=$(grep -o '"apiKey": *"[^"]*' "$f" | head -1 | sed 's/.*"//')"
f=$(find "$D/bazarr" -maxdepth 4 \( -name config.yaml -o -name config.ini \) 2>/dev/null | head -1)
[ -n "$f" ] && echo "bazarr=$(grep -i -m1 apikey "$f" | sed "s/.*[:=] *//; s/[\"' ]//g")"
p=${PLEX_PREFS:-/volume1/PlexMediaServer/AppData/Plex Media Server/Preferences.xml}
[ -f "$p" ] && echo "plex=$(grep -o 'PlexOnlineToken="[^"]*' "$p" | sed 's/.*"//')"
