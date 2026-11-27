#!/bin/bash
# THE one command for the MilkDrop visualizer and the moving Hearth fire (run on the Mac, Hearth open on the TV):
#   bash <(curl -sL https://raw.githubusercontent.com/elina-studio/hearth/<commit>/tools/viz/setup-viz.sh) <commit>
# 1. updates the NAS helper (it now has ffmpeg and joins pictures + song into one stream for the TV)
# 2. puts every key back on the NAS backup and the TV (the fire stream reads your fire clip from Plex with the Plex key)
# 3. checks the new helper and prints the one command to paste on the NucBox (PowerShell as administrator)
# Asks for the NAS ssh and sudo passwords as it goes. Plain bash 3.2, so it runs on the Mac as it is.
SHA=${1:?need the commit}
NAS="Elina@192.168.254.41"
CTL="-o ControlMaster=auto -o ControlPath=/tmp/hearth-ssh-%r-%h -o ControlPersist=300"
export HEARTH_BRANCH=${HEARTH_BRANCH:-claude/project-thread-939lqu}

echo "=== Part 1 and 2: update the helper, put the keys back ==="
bash <(curl -sL "https://raw.githubusercontent.com/elina-studio/hearth/$SHA/tools/remote/setup-all.sh") "$SHA" || { echo "Stopped (the lines above say why). Send them to me."; exit 1; }

echo
echo "=== Part 3: checking the new helper ==="
OUT=/tmp/hearth-viz-$$.out
# one NAS session reads the house key and asks the helper how it is (a second ssh can't use the sudo sign-in)
ssh -t $CTL "$NAS" 'sudo -v && K=$(sudo cat /volume1/docker/hearth-remote/data/helper-token 2>/dev/null | tr -d "\r\n"); echo "HEARTHKEY:$K"' | tee "$OUT" | grep -v HEARTHKEY
K=$(tr -d '\r' < "$OUT" | grep -o 'HEARTHKEY:[0-9a-f]*' | cut -d: -f2)
rm -f "$OUT"
if [ -z "$K" ]; then echo "Could not read the house key from the NAS. Send me the lines above."; exit 1; fi
ST=$(curl -s --max-time 10 -H "X-Hearth-Token: $K" http://192.168.254.41:8765/api/viz/status)
echo "   Helper says: $ST"
echo "$ST" | grep -q '"ffmpeg": true' || { echo "The helper is running but without ffmpeg, so the update didn't take. Send me the lines above."; exit 1; }
echo "   OK: the helper can join pictures and songs."
echo
echo "=== The NucBox ==="
# the NucBox says hello every minute; the helper just restarted, so give it a moment
for i in 1 2 3 4 5 6 7 8; do
  echo "$ST" | grep -q '"nucbox": {' && break
  sleep 10
  ST=$(curl -s --max-time 10 -H "X-Hearth-Token: $K" http://192.168.254.41:8765/api/viz/status)
done
if echo "$ST" | grep -q '"nucbox": {.*"renderer": "[0-9a-f]'; then
  echo "   The NucBox updates itself from the helper: nothing to do there. It takes the new version within a minute"
  echo "   and makes any missing loops on its own, between songs."
  NUC=ok
else
  if echo "$ST" | grep -q '"nucbox": {'; then
    echo "   The NucBox is on but runs an older renderer that can't update itself yet."
  else
    echo "   The NucBox didn't say hello (off, asleep, or the renderer isn't running)."
  fi
  echo "   ONE TIME ONLY: on the NucBox, open PowerShell as administrator and paste this line (no key in it)."
  echo "   After this the NucBox updates itself and never needs a step again."
  echo
  printf '%s\n' "\$c='$SHA'; & ([scriptblock]::Create((irm https://raw.githubusercontent.com/elina-studio/hearth/\$c/tools/viz/install.ps1))) -Commit \$c -SkipLoops"
  NUC=todo
fi
echo
echo "The Hearth fire view needs nothing more: it works as soon as the helper is updated."
