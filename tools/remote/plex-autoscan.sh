#!/bin/bash
# Hearth: make Sonarr + Radarr tell Plex to scan after every import.
# Run on the Mac: bash plex-autoscan.sh   (it copies itself to the NAS and runs there)
NAS=Elina@192.168.254.41

if [ "$1" != "--nas" ]; then
  ssh "$NAS" 'cat > /tmp/hearth-plex.sh' < "$0" || exit 1
  ssh -t "$NAS" 'sudo -v && sudo bash /tmp/hearth-plex.sh --nas; rm -f /tmp/hearth-plex.sh'
  exit $?
fi

# ---------- runs on the NAS as root ----------
PLEXPREF="/volume1/PlexMediaServer/AppData/Plex Media Server/Preferences.xml"
TOKEN=$(grep -o 'PlexOnlineToken="[^"]*"' "$PLEXPREF" | head -1 | cut -d'"' -f2)
[ -n "$TOKEN" ] || { echo "FAIL: no Plex token found"; exit 1; }
NAME="Hearth Plex"

setup() {  # $1 label  $2 port  $3 config.xml path
  label=$1; port=$2; cfg=$3
  [ -f "$cfg" ] || cfg=$(find /volume1/docker -maxdepth 4 -name config.xml -path "*$(echo "$label" | tr A-Z a-z)*" 2>/dev/null | head -1)
  KEY=$(grep -o '<ApiKey>[^<]*' "$cfg" 2>/dev/null | head -1 | cut -d'>' -f2)
  [ -n "$KEY" ] || { echo "FAIL: $label API key not found"; return 1; }
  base="http://127.0.0.1:$port/api/v3"
  if ! curl -s -H "X-Api-Key: $KEY" "$base/notification/schema" | grep -q PlexServer; then
    echo "FAIL: $label has no PlexServer notification type"; return 1
  fi
  id=$(curl -s -H "X-Api-Key: $KEY" "$base/notification" | awk -v n="$NAME" '
    /^  \{/ {id="";nm=""}
    /^    "id":/ {id=$2; gsub(/,/,"",id)}
    /^    "name":/ {nm=$0; sub(/^    "name": *"/,"",nm); sub(/",?$/,"",nm)}
    /^  \}/ {if (nm==n) print id}' | head -1)
  idpart=""; method=POST; url="$base/notification?forceSave=true"
  if [ -n "$id" ]; then idpart="\"id\":$id,"; method=PUT; url="$base/notification/$id?forceSave=true"; fi
  body="{${idpart}\"name\":\"$NAME\",\"implementation\":\"PlexServer\",\"configContract\":\"PlexServerSettings\",\"onGrab\":false,\"onDownload\":true,\"onUpgrade\":true,\"onRename\":true,\"onSeriesDelete\":true,\"onEpisodeFileDelete\":true,\"onEpisodeFileDeleteForUpgrade\":true,\"onMovieDelete\":true,\"onMovieFileDelete\":true,\"onMovieFileDeleteForUpgrade\":true,\"includeHealthWarnings\":false,\"tags\":[],\"fields\":[{\"name\":\"host\",\"value\":\"192.168.254.41\"},{\"name\":\"port\",\"value\":32400},{\"name\":\"useSsl\",\"value\":false},{\"name\":\"authToken\",\"value\":\"$TOKEN\"},{\"name\":\"updateLibrary\",\"value\":true}]}"
  code=$(curl -s -o /tmp/hearth-plex.out -w '%{http_code}' -X $method -H "X-Api-Key: $KEY" -H 'Content-Type: application/json' -d "$body" "$url")
  case $code in 200|201|202) echo "OK: $label -> Plex connection saved ($method)";; *) echo "FAIL: $label HTTP $code: $(head -c 300 /tmp/hearth-plex.out)"; return 1;; esac
}

R=0
setup Sonarr 8989 /volume1/docker/sonarr/config/config.xml || R=1
setup Radarr 7878 /volume1/docker/radarr/config/config.xml || R=1

# Scan every Plex library now
curl -s -o /dev/null "http://127.0.0.1:32400/library/sections/all/refresh?X-Plex-Token=$TOKEN" && echo "OK: Plex scan started"

# Overseerr Plex sync (best effort)
OS=/volume1/docker/overseerr/config/settings.json
OK=$(grep -o '"apiKey": *"[^"]*"' "$OS" 2>/dev/null | head -1 | cut -d'"' -f4)
if [ -n "$OK" ]; then
  curl -s -o /dev/null -X POST -H "X-Api-Key: $OK" -H 'Content-Type: application/json' -d '{"start":true}' http://127.0.0.1:5055/api/v1/settings/plex/sync && echo "OK: Overseerr sync started"
fi
[ $R = 0 ] && echo "DONE: new downloads will now appear in Plex automatically."
exit $R
