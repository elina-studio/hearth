#!/bin/bash
# One command that sets up the weather on Home and the screensaver: checks the Home Assistant token, finds the weather entity,
# saves them in the NAS helper's backup (so every launch restores them) and sends them to the TV.
#   bash <(curl -sL https://raw.githubusercontent.com/elina-studio/hearth/claude/project-thread-1503b3/tools/remote/ha-weather.sh)
# You paste the Home Assistant long-lived token once (hidden). Nothing is printed back.
NAS=${NAS:-Elina@192.168.254.41}; TV=${TV:-192.168.254.9}; HA=${HA:-http://192.168.254.41:8123}
KEYS=${KEYS:-/volume1/docker/hearth-remote/data/hearth-keys.json}
read -r -s -p "Paste the Home Assistant long-lived token (hidden): " TOK; echo
TOK=$(printf '%s' "$TOK" | tr -d ' \r\n"')
[ -z "$TOK" ] && { echo "No token entered, nothing changed."; exit 1; }

echo "Checking Home Assistant at $HA ..."
CODE=$(curl -s -m 10 -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $TOK" "$HA/api/")
case $CODE in
  200) echo "  token accepted";;
  401) echo "  Home Assistant refused the token (401). Make a new one and paste the whole thing; nothing was changed."; exit 1;;
  000) echo "  no answer from $HA. Is Home Assistant running? Nothing was changed."; exit 1;;
  *)   echo "  unexpected answer $CODE from Home Assistant. Nothing was changed."; exit 1;;
esac
LIST=$(curl -s -m 20 -H "Authorization: Bearer $TOK" "$HA/api/states" | grep -oE '"entity_id": *"weather\.[A-Za-z0-9_]+"' | sed -E 's/.*"(weather\.[^"]*)"/\1/')
if [ -z "$LIST" ]; then
  echo "  Home Assistant has no weather entity. In Home Assistant: Settings > Devices & services > Add integration > Meteorologisk institutt (Met.no), then run this again. Nothing was changed."
  exit 1
fi
ENT=$(echo "$LIST" | grep -x 'weather.forecast_home' | head -1)
[ -z "$ENT" ] && ENT=$(echo "$LIST" | grep -x 'weather.home' | head -1)
[ -z "$ENT" ] && ENT=$(echo "$LIST" | head -1)
echo "  weather entity: $ENT"
ST=$(curl -s -m 10 -H "Authorization: Bearer $TOK" "$HA/api/states/$ENT" | grep -oE '"state": *"[^"]*"' | head -1 | sed -E 's/.*"([^"]*)"$/\1/')
echo "  right now: ${ST:-unknown}"

echo "Saving a copy on the NAS helper (sudo password once)..."
CTL="-o ControlMaster=auto -o ControlPath=/tmp/hearth-ssh-%r-%h -o ControlPersist=120"
ssh -t $CTL "$NAS" "sudo -v" || exit 1
OLD=$(ssh $CTL "$NAS" "sudo cat $KEYS" 2>/dev/null | tr -d '\r'); OLD=${OLD:-\{\}}
OLD=$(echo "$OLD" | sed -E 's/"(haUrl|haToken|haEntity)": *"[^"]*",? *//g; s/,[[:space:]]*}/}/')
NEW="${OLD%\}}"; case "$NEW" in "{"|"") SEP="";; *) SEP=",";; esac
NEW="$NEW$SEP\"haUrl\":\"$HA\",\"haToken\":\"$TOK\",\"haEntity\":\"$ENT\"}"
printf '%s' "$NEW" | ssh $CTL "$NAS" "sudo tee $KEYS >/dev/null && sudo chmod 600 $KEYS" && echo "  saved on the NAS"

echo "Sending to the TV (Hearth must be open on it)..."
curl -s -m 10 -X POST -G --data-urlencode "haUrl=$HA" --data-urlencode "haToken=$TOK" --data-urlencode "haEntity=$ENT" "http://$TV:8060/input" >/dev/null && echo "  sent"
echo "Restarting Hearth so Home asks for the weather right away..."
sleep 1; curl -s -m 10 -X POST "http://$TV:8060/keypress/Home" >/dev/null; sleep 2; curl -s -m 10 -X POST "http://$TV:8060/launch/dev" >/dev/null
echo "Done. The weather line shows top right on Home a few seconds after Hearth opens (refreshed every 15 minutes)."
