#!/bin/bash
# Finds the Overseerr key that really works, sends it to the TV, and fixes the NAS copy.
# Never prints a key. Run on the Mac.
NAS="Elina@192.168.254.41"; TV="192.168.254.9"; U=http://192.168.254.41:5055
CTL="-o ControlMaster=auto -o ControlPath=/tmp/hearth-ssh-%r-%h -o ControlPersist=300"
ssh -t $CTL "$NAS" "sudo -v" || { echo "sudo failed: the NAS admin password was not accepted (nothing was changed). Run this again and type it carefully at the second prompt."; exit 1; }
OUT=$(ssh -t $CTL "$NAS" 'F=$(sudo find /volume1/docker -maxdepth 6 -name settings.json 2>/dev/null | grep -i seerr | head -1); echo "FILE=$F"; for k in $(sudo grep -oE "apiKey\": \"[^\"]+" "$F" | cut -d\" -f3); do c=$(curl -s -o /dev/null -w "%{http_code}" -H "X-Api-Key: $k" "'$U'/api/v1/request?take=1"); echo "CODE=$c"; [ "$c" = 200 ] && echo "GOOD=$k" && break; done' 2>/dev/null | tr -d '\r')
echo "$OUT" | grep -E "^(FILE|CODE)="
KEY=$(echo "$OUT" | grep '^GOOD=' | head -1 | cut -d= -f2-)
echo "$OUT" | grep -q "^FILE=.\+" || { echo "sudo failed or settings.json not found, so no key was checked (nothing was changed). Run this again and type the NAS password carefully."; exit 1; }
[ -z "$KEY" ] && { echo "No working key found in settings.json. Tell me the lines above."; exit 1; }
curl -s -X POST -G --data-urlencode "overseerrUrl=$U" --data-urlencode "overseerrKey=$KEY" "http://$TV:8060/input" && echo "sent to the TV"
ssh -t $CTL "$NAS" "sudo sed -i 's/\"overseerrKey\": *\"[^\"]*\"/\"overseerrKey\":\"$KEY\"/' /volume1/docker/hearth-remote/data/hearth-keys.json && echo fixed the NAS copy"
echo "Done. Open Requests on the TV (leave and re-enter Hearth if it is already open)."
