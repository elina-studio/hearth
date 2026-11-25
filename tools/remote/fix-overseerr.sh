#!/bin/bash
# Finds the Overseerr key that really works, then (from the NAS itself) sends it to the TV
# and fixes the NAS copy. One ssh session, one sudo, no key is ever printed.
NAS="Elina@192.168.254.41"
REMOTE=$(cat <<'EOF'
U=http://192.168.254.41:5055
TV=192.168.254.9
echo "Overseerr status: $(curl -s -o /dev/null -w '%{http_code}' $U/api/v1/status)"
F=$(find /volume1/docker -maxdepth 6 -name settings.json 2>/dev/null | grep -i seerr | head -1)
echo "settings file: ${F:-NOT FOUND}"
[ -z "$F" ] && { echo "folders in /volume1/docker:"; ls /volume1/docker; exit 1; }
J=/volume1/docker/hearth-remote/data/hearth-keys.json
NK=$(grep -oE 'overseerrKey":"[^"]+' "$J" 2>/dev/null | cut -d'"' -f3)
echo "NAS saved copy -> HTTP $(curl -s -o /dev/null -w '%{http_code}' -H "X-Api-Key: $NK" "$U/api/v1/request?take=1") (000 = none saved)"
n=0
for k in $(grep -oE 'apiKey": "[^"]+' "$F" | cut -d'"' -f3); do
  n=$((n+1))
  c=$(curl -s -o /dev/null -w '%{http_code}' -H "X-Api-Key: $k" "$U/api/v1/request?take=1")
  echo "key #$n -> HTTP $c"
  if [ "$c" = 200 ]; then
    curl -s -X POST -G --data-urlencode "overseerrUrl=$U" --data-urlencode "overseerrKey=$k" "http://$TV:8060/input" && echo "sent to the TV"
    J=/volume1/docker/hearth-remote/data/hearth-keys.json
    if [ -f "$J" ]; then sed -i "s/\"overseerrKey\": *\"[^\"]*\"/\"overseerrKey\":\"$k\"/" "$J" && echo "fixed the NAS copy"; else echo "no NAS copy file found at $J"; fi
    echo "DONE"
    exit 0
  fi
done
echo "No key in settings.json worked (checked $n)."
exit 1
EOF
)
B=$(printf '%s' "$REMOTE" | base64 | tr -d '\n')
ssh -t "$NAS" "echo $B | base64 -d > /tmp/hearth-ov.sh && sudo sh /tmp/hearth-ov.sh; rm -f /tmp/hearth-ov.sh"
