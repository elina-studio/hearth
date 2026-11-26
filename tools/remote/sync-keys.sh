#!/bin/bash
# One command that puts EVERY key back, on the TV and in the NAS helper's saved copy (so every launch can restore them).
#   bash <(curl -sL https://raw.githubusercontent.com/elina-studio/hearth/<commit>/tools/remote/sync-keys.sh)
# It reads each key from its own app on the NAS (Sonarr, Radarr, Lidarr, Overseerr, Bazarr, Plex, Home Assistant), rewrites
# /volume1/docker/hearth-remote/data/hearth-keys.json with all of them,
# and sends them to the TV. One ssh, one sudo password. No key is ever printed.
NAS="Elina@192.168.254.41"
REMOTE=$(cat <<'EOF'
D=/volume1/docker
TV=192.168.254.9
J=$D/hearth-remote/data/hearth-keys.json
for a in sonarr radarr lidarr; do
  f=$(ls "$D/$a/config/config.xml" "$D/$a/config.xml" 2>/dev/null | head -1)
  v=""; [ -n "$f" ] && v=$(grep -o '<ApiKey>[^<]*' "$f" | head -1 | sed 's/<ApiKey>//')
  eval "K_$a=\$v"
done
f=$(find "$D" -maxdepth 6 -name settings.json 2>/dev/null | grep -i seerr | head -1)
K_overseerr=""; [ -n "$f" ] && K_overseerr=$(grep -o '"apiKey": *"[^"]*' "$f" | head -1 | sed 's/.*"//')
f=$(find "$D/bazarr" -maxdepth 4 \( -name config.yaml -o -name config.ini \) 2>/dev/null | head -1)
K_bazarr=""; [ -n "$f" ] && K_bazarr=$(grep -i -m1 apikey "$f" | sed "s/.*[:=] *//; s/[\"' ]//g")
p="/volume1/PlexMediaServer/AppData/Plex Media Server/Preferences.xml"
K_plex=""; [ -f "$p" ] && K_plex=$(grep -o 'PlexOnlineToken="[^"]*' "$p" | sed 's/.*"//')
old() { grep -oE "\"$1\": *\"[^\"]*\"" "$J" 2>/dev/null | head -1 | sed -E 's/.*: *"(.*)"/\1/'; }
# a key this run can't find keeps whatever the NAS copy already had
[ -z "$K_plex" ] && K_plex=$(old plexToken)
for n in overseerr lidarr bazarr radarr sonarr; do
  eval "[ -z \"\$K_$n\" ] && K_$n=\$(old ${n}Key)"
done
# Home Assistant (weather + speakers): reuse the saved token if HA still takes it, otherwise sign a fresh one from a
# long-lived token HA already has (its own auth store holds the signing key), so nobody has to make one by hand.
DK=/usr/local/bin/docker
HAU="$(old haUrl)"; [ -z "$HAU" ] && HAU="http://192.168.254.41:8123"
hacode() { curl -s -o /dev/null -m 8 -w '%{http_code}' -H "Authorization: Bearer $1" "$HAU/api/$2"; }
K_ha="$(old haToken)"
[ -n "$K_ha" ] && [ "$(hacode "$K_ha" "")" != "200" ] && K_ha=""
if [ -z "$K_ha" ]; then
  HAC=$($DK ps --format '{{.Names}}' 2>/dev/null | grep -i -m1 -E '^home-?assistant$')
  cat > /tmp/hearth-ha.py <<'PY'
import json, time, jwt
a = json.load(open("/config/.storage/auth"))["data"]
users = {u["id"]: u for u in a.get("users", [])}
ll = [t for t in a.get("refresh_tokens", []) if t.get("token_type") == "long_lived_access_token"
      and users.get(t.get("user_id"), {}).get("is_active", True)]
ll.sort(key=lambda t: ("hearth" in (t.get("client_name") or "").lower(), t.get("created_at") or ""), reverse=True)
if ll:
    t, now = ll[0], int(time.time())
    print(jwt.encode({"iss": t["id"], "iat": now, "exp": now + int(t.get("access_token_expiration") or 315360000)}, t["jwt_key"], algorithm="HS256"))
PY
  [ -n "$HAC" ] && K_ha=$($DK exec -i "$HAC" python3 - < /tmp/hearth-ha.py 2>/dev/null)
  rm -f /tmp/hearth-ha.py
  [ -n "$K_ha" ] && [ "$(hacode "$K_ha" "")" != "200" ] && K_ha=""
fi
HAE="$(old haEntity)"; [ -z "$HAE" ] && HAE="weather.forecast_home"
if [ -n "$K_ha" ] && [ "$(hacode "$K_ha" "states/$HAE")" != "200" ]; then
  e=$(curl -s -m 8 -H "Authorization: Bearer $K_ha" "$HAU/api/states" | grep -o '"entity_id": *"weather\.[^"]*"' | head -1 | sed 's/.*"\(weather\.[^"]*\)"/\1/')
  [ -n "$e" ] && HAE="$e"
fi
OUT="{"
add() { [ -n "$2" ] && OUT="$OUT\"$1\":\"$2\","; }
add plexToken "$K_plex"; add plexServerToken "$K_plex"
add plexServer "$(old plexServer)"; [ -z "$(old plexServer)" ] && add plexServer "http://192.168.254.41:32400"
add plexServerName "$(old plexServerName)"
add overseerrUrl "http://192.168.254.41:5055"; add overseerrKey "$K_overseerr"
add lidarrUrl "http://192.168.254.41:8686";    add lidarrKey "$K_lidarr"
add bazarrUrl "http://192.168.254.41:6767";    add bazarrKey "$K_bazarr"
add radarrUrl "http://192.168.254.41:7878";    add radarrKey "$K_radarr"
add sonarrUrl "http://192.168.254.41:8989";    add sonarrKey "$K_sonarr"
if [ -n "$K_ha" ]; then add haUrl "$HAU"; add haToken "$K_ha"; add haEntity "$HAE"; fi
OUT="${OUT%,}}"
for n in plex overseerr lidarr bazarr radarr sonarr; do
  eval "v=\$K_$n"; [ -n "$v" ] && echo "  found $n" || echo "  MISSING $n (not changed)"
done
if [ -n "$K_ha" ]; then echo "  found Home Assistant (weather: $HAE, HTTP $(hacode "$K_ha" "states/$HAE"))"; else echo "  MISSING Home Assistant: no working token and no long-lived token in HA to sign one from"; fi
mkdir -p "$D/hearth-remote/data"
printf '%s' "$OUT" > "$J" && chmod 600 "$J" && echo "saved on the NAS helper"
[ -n "$K_overseerr" ] && curl -s -X POST -G --data-urlencode "overseerrUrl=http://192.168.254.41:5055" --data-urlencode "overseerrKey=$K_overseerr" "http://$TV:8060/input"
[ -n "$K_lidarr" ]    && curl -s -X POST -G --data-urlencode "lidarrUrl=http://192.168.254.41:8686" --data-urlencode "lidarrKey=$K_lidarr" "http://$TV:8060/input"
[ -n "$K_bazarr" ]    && curl -s -X POST -G --data-urlencode "bazarrUrl=http://192.168.254.41:6767" --data-urlencode "bazarrKey=$K_bazarr" "http://$TV:8060/input"
[ -n "$K_radarr" ]    && curl -s -X POST -G --data-urlencode "radarrUrl=http://192.168.254.41:7878" --data-urlencode "radarrKey=$K_radarr" "http://$TV:8060/input"
[ -n "$K_sonarr" ]    && curl -s -X POST -G --data-urlencode "sonarrUrl=http://192.168.254.41:8989" --data-urlencode "sonarrKey=$K_sonarr" "http://$TV:8060/input"
[ -n "$K_ha" ]        && curl -s -X POST -G --data-urlencode "haUrl=$HAU" --data-urlencode "haToken=$K_ha" --data-urlencode "haEntity=$HAE" "http://$TV:8060/input"
echo "sent to the TV (Hearth must be open for the TV to take them)"
echo
echo "Checking everything Music > Discover leans on (the first look at Lidarr can take a few minutes)..."
T=$(cat $D/hearth-remote/data/helper-token 2>/dev/null)
curl -s -m 20 -H "X-Hearth-Token: $T" "http://127.0.0.1:8765/api/discover?refresh=1" >/dev/null
R=$(curl -s -m 420 -H "X-Hearth-Token: $T" "http://127.0.0.1:8765/api/discover/selftest")
case "$R" in
  *OK*|*FAIL*) echo "$R" ;;
  *) echo "  The helper didn't answer the check. Send me this whole output." ;;
esac
EOF
)
B=$(printf '%s' "$REMOTE" | base64 | tr -d '\n')
ssh -t -o ControlMaster=auto -o ControlPath=/tmp/hearth-ssh-%r-%h -o ControlPersist=300 "$NAS" "echo $B | base64 -d > /tmp/hearth-sync.sh && sudo sh /tmp/hearth-sync.sh; rm -f /tmp/hearth-sync.sh"
