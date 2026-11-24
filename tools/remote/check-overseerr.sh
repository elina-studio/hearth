#!/bin/bash
# Prints only HTTP status codes (never keys): 200 = key works, 401/403 = wrong key.
NAS="Elina@192.168.254.41"
ssh -t "$NAS" 'sudo -v && U=http://192.168.254.41:5055
echo "Overseerr up: $(curl -s -o /dev/null -w "%{http_code}" $U/api/v1/status)"
K=$(sudo grep -oE "overseerrKey\":\"[^\"]+" /volume1/docker/hearth-remote/data/hearth-keys.json | cut -d\" -f3)
echo "NAS saved key: $(curl -s -o /dev/null -w "%{http_code}" -H "X-Api-Key: $K" "$U/api/v1/request?take=1")"
F=$(find /volume1/docker -maxdepth 5 -name settings.json 2>/dev/null | grep -i seerr | head -1)
echo "file: $F"
n=0
for k in $(sudo grep -oE "apiKey\": \"[^\"]+" "$F" | cut -d\" -f3); do n=$((n+1)); echo "settings.json key #$n: $(curl -s -o /dev/null -w "%{http_code}" -H "X-Api-Key: $k" "$U/api/v1/request?take=1")"; done'
