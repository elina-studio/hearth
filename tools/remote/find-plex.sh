#!/bin/sh
# Runs on the NAS (as root, via fix-plex.sh). Looks for the Plex server's own sign-in token.
ROOT=${FIND_ROOT:-/volume1}
find "$ROOT" -maxdepth 8 -name Preferences.xml -path '*Plex Media Server*' 2>/dev/null | while IFS= read -r p; do
  t=$(grep -o 'PlexOnlineToken="[^"]*' "$p" | sed 's/.*"//')
  echo "looked in: $p (token $([ -n "$t" ] && echo found || echo MISSING))"
  if [ -n "$t" ]; then echo "plex=$t"; break; fi
done
