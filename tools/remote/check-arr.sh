#!/bin/bash
# Why did Overseerr mark a request Failed? Runs a check from inside the Overseerr container
# (so it sees exactly what Overseerr sees) against Sonarr and Radarr. Prints no keys.
# Usage: bash <(curl -sL https://raw.githubusercontent.com/elina-studio/hearth/COMMIT/tools/remote/check-arr.sh) COMMIT
D="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
if [ -f "$D/check-arr.js" ]; then
  B=$(base64 < "$D/check-arr.js" | tr -d '\n')
else
  B=$(curl -sL "https://raw.githubusercontent.com/elina-studio/hearth/$1/tools/remote/check-arr.js" | base64 | tr -d '\n')
fi
ssh -t Elina@192.168.254.41 "sudo -v && echo $B | base64 -d | sudo /usr/local/bin/docker exec -i overseerr node -"
