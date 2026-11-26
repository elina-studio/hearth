#!/bin/bash
# Sonarr returned 500 "database ..." to Overseerr. Show the Sonarr log lines, restart Sonarr,
# then retry every Failed request in Overseerr. One ssh session. Prints no keys.
# Usage: bash <(curl -sL https://raw.githubusercontent.com/elina-studio/hearth/COMMIT/tools/remote/fix-sonarr-db.sh) COMMIT
U="https://raw.githubusercontent.com/elina-studio/hearth/$1/tools/remote"
R=$(curl -sL "$U/fix-sonarr-db.remote.sh" | base64 | tr -d '\n')
J=$(curl -sL "$U/fix-sonarr-db.js" | base64 | tr -d '\n')
ssh -t Elina@192.168.254.41 "sudo -v && echo $J | base64 -d > /tmp/hf.js && echo $R | base64 -d > /tmp/hf.sh && bash /tmp/hf.sh; rm -f /tmp/hf.js /tmp/hf.sh"
