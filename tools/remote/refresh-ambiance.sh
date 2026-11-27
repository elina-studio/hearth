#!/bin/bash
# Makes Plex re-read the Ambiance library (new clips like fireflies.mp4 / embers.mp4), then lists
# what Plex now has in it with codec and size. Never prints the Plex token.
NAS="Elina@192.168.254.41"
ssh -t "$NAS" 'sudo -v && P="/volume1/PlexMediaServer/AppData/Plex Media Server/Preferences.xml"
T=$(sudo grep -oE "PlexOnlineToken=\"[^\"]+" "$P" | cut -d\" -f2)
U=http://127.0.0.1:32400
SECS=$(curl -s -H "X-Plex-Token: $T" "$U/library/sections" | tr ">" "\n" | grep -iE "^<Directory.*title=\"[^\"]*(ambiance|ambience|hearth)" | grep -oE " key=\"[0-9]+" | cut -d\" -f2)
[ -z "$SECS" ] && { echo "No Plex library called Ambiance found."; exit 1; }
for S in $SECS; do
  echo "Asking Plex to rescan library $S ..."
  curl -s -X GET -H "X-Plex-Token: $T" "$U/library/sections/$S/refresh?force=1" >/dev/null
done
echo "Waiting 40 s for the scan ..."
sleep 40
for S in $SECS; do
  echo "== Plex library $S now has =="
  curl -s -H "X-Plex-Token: $T" "$U/library/sections/$S/all" | tr ">" "\n" | grep -E "^<(Video|Media|Part)" | grep -oE "(^<Video|file=\"[^\"]*\"|videoCodec=\"[^\"]*\"|height=\"[^\"]*\")" | tr "\n" " " | sed "s/<Video/\n/g"
  echo
done'
