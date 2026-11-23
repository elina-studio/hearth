#!/bin/bash
# Re-set one service's key on the TV (and in the NAS copy).  Usage on the Mac:
#   bash <(curl -sL https://raw.githubusercontent.com/elina-studio/hearth/claude/project-thread-3b4es1/tools/remote/set-key.sh) overseerr
# services: overseerr, radarr, sonarr, lidarr, bazarr   (ha = Home Assistant token)
NAS="Elina@192.168.254.41"; TV="192.168.254.9"
S=${1:-overseerr}
case $S in
  overseerr) P=5055;; radarr) P=7878;; sonarr) P=8989;; lidarr) P=8686;; bazarr) P=6767;; ha) P=8123;;
  *) echo "unknown service $S"; exit 1;;
esac
if [ "$S" = ha ]; then UK=haUrl; KK=haToken; else UK=${S}Url; KK=${S}Key; fi
read -r -p "$S address [http://192.168.254.41:$P]: " URL; URL=${URL:-http://192.168.254.41:$P}
read -r -s -p "Paste the $S key (hidden): " KEY; echo
[ -z "$KEY" ] && { echo "No key entered, nothing changed."; exit 1; }
curl -s -X POST -G --data-urlencode "$UK=$URL" --data-urlencode "$KK=$KEY" "http://$TV:8060/input" && echo "sent to the TV"
OLD=$(curl -s --max-time 4 http://192.168.254.41:8765/api/keys); OLD=${OLD:-\{\}}
OLD=$(echo "$OLD" | sed -E "s/\"$UK\": *\"[^\"]*\",? *//; s/\"$KK\": *\"[^\"]*\",? *//; s/,\\s*}/}/")
NEW="${OLD%\}}"; [ "$NEW" = "{" ] && SEP="" || SEP=","
NEW="$NEW$SEP\"$UK\":\"$URL\",\"$KK\":\"$KEY\"}"
printf '%s' "$NEW" | ssh -t "$NAS" "sudo tee /volume1/docker/hearth-remote/data/hearth-keys.json >/dev/null && echo saved on the NAS"
