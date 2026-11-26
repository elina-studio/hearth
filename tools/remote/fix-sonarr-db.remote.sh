#!/bin/bash
# Runs on the NAS (needs sudo already cached). Prints no keys.
D=/usr/local/bin/docker
echo "== Sonarr log: database errors (newest last)"
L=$(ls /volume1/docker/sonarr/config/logs/sonarr.txt 2>/dev/null | head -1)
if [ -n "$L" ]; then
  sudo grep -i -E "database|locked|sqlite|disk i/o|malformed" "$L" | tail -6 | cut -c1-300
else
  echo "(log file not found)"
fi
echo
echo "== Restarting Sonarr (clears a stuck database lock)"
sudo $D restart sonarr >/dev/null
n=0
while [ $n -lt 30 ]; do
  c=$(curl -s -o /dev/null -w "%{http_code}" http://192.168.254.41:8989/ping)
  if [ "$c" = "200" ]; then break; fi
  n=$((n+1)); sleep 3
done
echo "Sonarr /ping after restart: $c"
echo
echo "== Retrying Failed requests in Overseerr"
sudo $D exec -i overseerr node - < /tmp/hf.js
