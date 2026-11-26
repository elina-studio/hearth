#!/bin/bash
# Lists what the Ambiance room can see: the Plex libraries, the clip files on disk, and what Plex
# says about each clip (codec, size). Never prints the Plex token.
NAS="Elina@192.168.254.41"
ssh -t "$NAS" 'sudo -v && P="/volume1/PlexMediaServer/AppData/Plex Media Server/Preferences.xml"
T=$(sudo grep -oE "PlexOnlineToken=\"[^\"]+" "$P" | cut -d\" -f2)
U=http://127.0.0.1:32400
show() { tr ">" "\n" | grep -E "^<(Directory|Video|Media|Part|Location)" | while read -r line; do echo "$line" | grep -oE "(^<[A-Za-z]+|title=\"[^\"]*\"|type=\"[^\"]*\"|key=\"[^\"]*\"|path=\"[^\"]*\"|file=\"[^\"]*\"|container=\"[^\"]*\"|videoCodec=\"[^\"]*\"|width=\"[^\"]*\"|height=\"[^\"]*\")" | tr "\n" " "; echo; done; }
echo "== Plex libraries =="
curl -s -H "X-Plex-Token: $T" "$U/library/sections" | show
echo
echo "== Files on disk (hearth folders) =="
for d in /volume1/plex/plex/hearth /volume1/plex/hearth /volume1/plex/plex/movies/hearth; do [ -d "$d" ] && { echo "$d"; ls -la "$d"; }; done
echo
for S in $(curl -s -H "X-Plex-Token: $T" "$U/library/sections" | tr ">" "\n" | grep -iE "^<Directory.*title=\"[^\"]*(ambiance|ambience|hearth)" | grep -oE " key=\"[0-9]+" | cut -d\" -f2); do
  echo "== Plex section $S: what it returns for each clip =="
  curl -s -H "X-Plex-Token: $T" "$U/library/sections/$S/all" | show
done
echo
echo "== Plex scanner log lines about hearth/rain (last 10) =="
sudo grep -ihE "rain|hearth" "/volume1/PlexMediaServer/AppData/Plex Media Server/Logs/Plex Media Server.log" 2>/dev/null | grep -iE "error|fail|unsupported|ignor" | tail -10'
