#!/bin/bash
# One command: send a build to the TV and say plainly whether it installed or failed to compile.
# Usage:  bash tools/sideload.sh ~/Downloads/hearth-build-79.zip
# It asks for the TV's developer password (the one you set when you turned on developer mode); nothing is stored.
ZIP="${1:?usage: bash tools/sideload.sh path/to/hearth-build-N.zip}"
TV=192.168.254.9
[ -f "$ZIP" ] || { echo "No such file: $ZIP"; exit 1; }
read -s -p "TV developer password: " PW; echo
OUT=$(curl -s --digest -u "rokudev:$PW" -F "mysubmit=Install" -F "archive=@$ZIP" "http://$TV/plugin_install")
echo "$OUT" | grep -qi "unauthorized" && { echo "WRONG PASSWORD (or developer mode is off)."; exit 1; }
MSG=$(echo "$OUT" | sed -e 's/<[^>]*>/ /g' | tr -s ' \n' ' ' | grep -oiE "(Install Success|Install Failure|Application Received|Identical to previous)[^.]*\.?[^.]*\.?" | head -3)
echo "TV says: ${MSG:-nothing readable (open http://$TV in a browser to see)}"
if echo "$OUT" | grep -qi "Install Failure\|Compilation Failed"; then
  echo; echo "COMPILE FAILED. The TV's own error (send me this):"
  (printf '' | nc -w 3 $TV 8085 2>/dev/null | grep -iE "syntax|error|compile|\.brs|\.xml" | tail -15) || true
  exit 2
fi
echo "Installed. Launching..."; curl -s -X POST "http://$TV:8060/launch/dev" >/dev/null && echo "Done."
