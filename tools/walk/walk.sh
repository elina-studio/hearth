#!/bin/bash
# Hearth live walk: drives the real TV over ECP, presses every path, screenshots every press,
# records the TV's debug log, and writes a pass/fail report.   (bash 3.2 safe: macOS default shell)
#
# Usage (from the Mac Terminal, TV on):
#   bash <(curl -sL https://raw.githubusercontent.com/elina-studio/hearth/<commit>/tools/walk/walk.sh) <commit> [path ids...]
#
# What it needs: the Hearth build that prints the walk trace (build 110+). By default this script
# installs that build itself (tools/walk/hearth-walk-build.zip at the same commit) and launches it with ?walk=1.
# The TV's developer password is asked for once and never stored.
#
# Environment overrides (used by the local self-test): TV, ECP_PORT, WEB_PORT, LOG_PORT, WAIT, OUTBASE, NOINSTALL=1, ZIP=path

# the whole script is one block so bash reads all of it before running any of it
{
TV="${TV:-192.168.254.9}"
ECP_PORT="${ECP_PORT:-8060}"
WEB_PORT="${WEB_PORT:-80}"
LOG_PORT="${LOG_PORT:-8085}"
WAIT="${WAIT:-0.8}"
COMMIT="$1"; shift
ONLY="$*"
RAW="https://raw.githubusercontent.com/elina-studio/hearth"
STAMP=$(date +%Y%m%d-%H%M%S)
OUTBASE="${OUTBASE:-$HOME/Desktop}"
OUT="$OUTBASE/hearth-walk-$STAMP"
mkdir -p "$OUT/shots" || { echo "cannot make $OUT"; exit 1; }
LOG="$OUT/tv.log"; WLOG="$OUT/walk.log"; RES="$OUT/steps.tsv"; CFG="$OUT/.curlcfg"
: > "$LOG"; : > "$WLOG"; : > "$RES"
ECP="http://$TV:$ECP_PORT"
WEB="http://$TV:$WEB_PORT"

cleanup() {
  [ -n "$NCPID" ] && kill "$NCPID" 2>/dev/null
  pkill -P $$ 2>/dev/null
  pkill -f "nc -d $TV $LOG_PORT" 2>/dev/null
  rm -f "$CFG"
}
trap cleanup EXIT

say() { echo "$@"; }

# ---------------------------------------------------------------- password and TV checks
printf 'TV developer password: '
read -r -s PW; echo
[ -n "$PW" ] || { echo "No password given."; exit 1; }
umask 077
printf 'user = "rokudev:%s"\n' "$PW" > "$CFG"
umask 022

CODE=$(curl -s -m 8 -o /dev/null -w '%{http_code}' --digest -K "$CFG" "$WEB/")
if [ "$CODE" != "200" ]; then
  echo "The TV did not accept the developer login (HTTP $CODE). Check the password, that the TV is on, and developer mode is on."
  exit 1
fi
ACT=$(curl -s -m 5 "$ECP/query/device-info" | grep -o '<model-name>[^<]*' | head -1)
say "TV found: ${ACT#<model-name>}"

# ---------------------------------------------------------------- install the build that has the walk trace
if [ "$NOINSTALL" != "1" ]; then
  if [ -z "$ZIP" ]; then
    [ -n "$COMMIT" ] || { echo "Give the commit as the first argument."; exit 1; }
    ZIP="$OUT/hearth-walk-build.zip"
    say "Downloading the build..."
    curl -sfL -m 120 -o "$ZIP" "$RAW/$COMMIT/tools/walk/hearth-walk-build.zip" || { echo "Could not download the build for commit $COMMIT."; exit 1; }
  fi
  say "Installing on the TV..."
  INS=$(curl -s -m 120 --digest -K "$CFG" -F "mysubmit=Install" -F "archive=@$ZIP" "$WEB/plugin_install")
  if echo "$INS" | grep -qi "Install Failure\|Compilation Failed"; then
    echo "INSTALL FAILED:"; echo "$INS" | sed -e 's/<[^>]*>/ /g' | tr -s ' \n' ' ' | head -c 600; echo; exit 2
  fi
  echo "$INS" | grep -qi "Install Success\|Application Received\|Identical to previous" || { echo "The TV gave no install answer."; exit 2; }
  say "Installed."
  sleep 3
fi

# ---------------------------------------------------------------- debug log capture (port 8085, one client at a time)
# nc -d: never read the keyboard (a background job's input is closed, and plain nc would hang up at once).
# The loop reconnects whenever the TV drops the log (it does when the app restarts).
( while true; do nc -d "$TV" "$LOG_PORT"; sleep 1; done ) 2>/dev/null | tee -a "$LOG" | grep --line-buffered HWALK >> "$WLOG" &
NCPID=$!
sleep 2

launch() {
  curl -s -m 5 -X POST "$ECP/keypress/Home" >/dev/null
  sleep 3
  curl -s -m 8 -X POST "$ECP/launch/dev?walk=1" >/dev/null
}

# ---------------------------------------------------------------- state helpers (from the HWALK lines)
last_stack() { grep 'HWALK stack=' "$WLOG" | tail -1; }
last_key()   { grep 'HWALK key=' "$WLOG" | tail -1; }
top_screen() {
  s=$(last_stack); s=${s#*stack=}; s=${s%% focus=*}; s=${s%>}
  echo "${s##*>}"
}
has_dialog() { last_stack | grep -q 'dialog= music'; [ $? -ne 0 ]; }
in_pills() {
  s=$(last_stack)
  [ "$(top_screen)" = "HubScreen" ] || return 1
  echo "$s" | grep -q '#pills>' || return 1
  echo "$s" | grep -q 'dialog= music' || return 1
  return 0
}
app_alive() { curl -s -m 5 "$ECP/query/active-app" | grep -q 'id="dev"'; }

STEP=0; PATHID="boot"; PATHTITLE=""; PREVSUM=""; SHOTFAIL=0; CUR=0; ERRPOS=0
safe() { echo "$1" | tr '\t\r\n' '   ' | cut -c1-300; }

take_shot() {
  [ "$SHOTFAIL" -ge 5 ] && return 1
  HTML=$(curl -s -m 15 --digest -K "$CFG" -F "mysubmit=Screenshot" -F "archive=;filename=" "$WEB/plugin_inspect")
  IMG=$(echo "$HTML" | grep -oE 'pkgs/dev\.(jpg|png)[^"'"'"' >]*' | head -1)
  if [ -z "$IMG" ]; then SHOTFAIL=$((SHOTFAIL+1)); return 1; fi
  curl -s -m 20 --digest -K "$CFG" -o "$1" "$WEB/$IMG" || { SHOTFAIL=$((SHOTFAIL+1)); return 1; }
  [ -s "$1" ] || { SHOTFAIL=$((SHOTFAIL+1)); return 1; }
  SHOTFAIL=0
  return 0
}

ERRRE='BRIGHTSCRIPT: ERROR|Backtrace begin|Runtime Error|Type Mismatch|Dot Operator attempted|Function Call Operator|Member function not found|Invalid value|SIGSEGV|Syntax Error|Roku_Crash'
WARNRE='\[hearth[^]]*\].*([Ff]ail|[Ee]rror|can.t reach|[Tt]imed out|denied|refused)'

row() { # verdict key note shot state
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$PATHID" "$STEP" "$2" "$1" "$(safe "$3")" "$4" "$(safe "$5")" "$PATHTITLE" >> "$RES"
  if [ "$1" = "FAIL" ]; then echo "   FAIL  [$PATHID #$STEP $2] $3"; fi
}

# press KEY: send it, wait, screenshot, check log and app
press() {
  k="$1"
  STEP=$((STEP+1))
  b_log=$(wc -l < "$LOG" | tr -d ' ')
  b_w=$(wc -l < "$WLOG" | tr -d ' ')
  curl -s -m 5 -X POST "$ECP/keypress/$k" >/dev/null
  sleep "$WAIT"
  shot="shots/$(printf '%04d' $STEP)-$PATHID-$k.jpg"
  if take_shot "$OUT/$shot"; then SUM=$(cksum < "$OUT/$shot" | cut -d' ' -f1); else shot=""; SUM=""; fi
  newlog=$(tail -n +$((b_log+1)) "$LOG")
  newW=$(tail -n +$((b_w+1)) "$WLOG")
  kl=$(echo "$newW" | grep 'HWALK key=' | tail -1)
  sl=$(last_stack)
  st="${kl#HWALK }"; [ -n "$st" ] || st="(no key line)"
  v="PASS"; note=""
  errs=$(echo "$newlog" | grep -E "$ERRRE" | head -3)
  if [ -n "$errs" ]; then v="FAIL"; note="log error: $errs"; fi
  if ! app_alive; then
    v="FAIL"; note="app is not running after this press (crash or exit). $note"
    row "$v" "$k" "$note" "$shot" "$st"
    say "   App stopped; relaunching and carrying on."
    launch; wait_hub 60 || true
    PREVSUM=""
    return 1
  fi
  if [ "$v" = "PASS" ]; then
    w=$(echo "$newlog" | grep -E "$WARNRE" | head -1)
    if [ -n "$w" ]; then v="WARN"; note="app reported: $w"; fi
  fi
  if [ "$k" = "Select" ] && [ "$v" = "PASS" ] && [ -n "$SUM" ] && [ "$SUM" = "$PREVSUM" ] && [ -z "$newW" ]; then
    v="WARN"; note="OK changed nothing on screen and nothing in the state"
  fi
  [ -n "$SUM" ] && PREVSUM="$SUM"
  row "$v" "$k" "$note" "$shot" "$st | $(top_screen)"
  return 0
}
presses() { for kk in "$@"; do press "$kk"; done; }

# a check: PATTERN must match the current stack line + last key line
expect() { # label regex
  STEP=$((STEP+1))
  cur="$(last_stack) | $(last_key)"
  if echo "$cur" | grep -Eq "$2"; then row PASS "expect" "$1" "" "$(safe "$cur")"; return 0; fi
  shot="shots/$(printf '%04d' $STEP)-$PATHID-expect.jpg"
  take_shot "$OUT/$shot" || shot=""
  row FAIL "expect" "$1 (wanted /$2/)" "$shot" "$cur"
  return 1
}
expect_not() {
  STEP=$((STEP+1))
  cur="$(last_stack) | $(last_key)"
  if echo "$cur" | grep -Eq "$2"; then
    shot="shots/$(printf '%04d' $STEP)-$PATHID-expect.jpg"; take_shot "$OUT/$shot" || shot=""
    row FAIL "expect" "$1 (should not match /$2/)" "$shot" "$cur"; return 1
  fi
  row PASS "expect" "$1" "" "$(safe "$cur")"; return 0
}
note() { STEP=$((STEP+1)); row INFO "note" "$1" "" ""; }

# press KEY until the last key line matches PATTERN (at most MAX presses). Returns 1 if never reached.
go_zone() { # key regex max
  i=0
  while [ $i -lt "$3" ]; do
    if last_key | grep -Eq "$2"; then return 0; fi
    press "$1"; i=$((i+1))
  done
  last_key | grep -Eq "$2"
}
need() { # label key regex max : must reach, else fail the path step
  if go_zone "$2" "$3" "$4"; then return 0; fi
  STEP=$((STEP+1))
  shot="shots/$(printf '%04d' $STEP)-$PATHID-zone.jpg"; take_shot "$OUT/$shot" || shot=""
  row FAIL "zone" "$1: never reached /$3/ after $4 presses of $2 (no data, or a dead end)" "$shot" "$(last_key)"
  return 1
}

wait_hub() { # seconds
  i=0
  while [ $i -lt "$1" ]; do
    if last_stack | grep -q 'stack=HubScreen>'; then sleep 2; return 0; fi
    sleep 1; i=$((i+1))
  done
  return 1
}

wait_top() { # screen secs
  i=0
  while [ $i -lt "$2" ]; do
    [ "$(top_screen)" = "$1" ] && return 0
    sleep 1; i=$((i+1))
  done
  return 1
}

# Back until the room bar is focused, never pressing Back on the bar itself (that opens the leave prompt).
unwind() {
  i=0
  while [ $i -lt 10 ]; do
    if in_pills; then
      STEP=$((STEP+1)); row PASS "unwind" "Back reached the room bar after $i presses" "" "$(top_screen)"
      return 0
    fi
    press Back || true
    i=$((i+1))
  done
  if in_pills; then return 0; fi
  STEP=$((STEP+1)); shot="shots/$(printf '%04d' $STEP)-$PATHID-stuck.jpg"; take_shot "$OUT/$shot" || shot=""
  row FAIL "unwind" "Back could not reach the room bar in 10 presses" "$shot" "$(last_stack)"
  # recover so later paths can run
  launch; wait_hub 60 || true
  return 1
}

# Make the room bar current on Home, then move to room N and go in. 0 Home 1 Shows 2 Movies 3 Music 4 Requests 5 Ambiance 6 Photos 7 Search
goto_room() { # index
  unwind || true
  press Back
  sleep 1
  if has_dialog; then press Back; sleep 1; fi
  CUR=0
  n=$1; j=0
  while [ $j -lt "$n" ]; do press Right; j=$((j+1)); done
  press Down
  sleep 2
}

begin() { # id title
  PATHID="$1"; PATHTITLE="$2"
  if [ -n "$ONLY" ]; then
    echo " $ONLY " | grep -q " $1 " || return 1
  fi
  echo "== $1: $2"
  return 0
}

# ---------------------------------------------------------------- reusable walks
details_walk() {
  expect "Details screen is on top" 'stack=[^ ]*DetailsScreen> ' || return 1
  sleep 2
  presses Right Right Left Down Right Down Left Down Up Up Up
  if go_zone Up 'zone:act ' 6; then
    press Info; sleep 1; press Back
  fi
  if go_zone Down 'zone:eps ' 4; then
    presses Down Up
    press Right; sleep 1
    expect "episode sheet opened" 'SideSheet|focus=[^ ]*SideSheet'
    press Back
  elif go_zone Down 'zone:below ' 4; then
    presses Right Right Left Down Up
  fi
  return 0
}

play_walk() {
  if ! wait_top PlayerScreen 25; then STEP=$((STEP+1)); row FAIL "play" "Player did not open within 25 s" "" "$(last_stack)"; return 1; fi
  sleep 10
  note "player running; $(echo "$(grep -c '\[hearth-ui\]' "$LOG") player lines so far")"
  presses Down Down Right Right Right Select
  sleep 1
  presses Down Back Right Select
  sleep 1
  presses Back Right Right Right Right Right Right Right Right Right Right Right Right
  presses Left Left Select
  sleep 1
  presses Back Left Select
  sleep 1
  presses Back Up Right Left Back
  presses Play Play Info
  sleep 1
  presses Back Rev Fwd InstantReplay Left Right
  press Back
  sleep 1
  if [ "$(top_screen)" = "PlayerScreen" ]; then press Back; sleep 1; fi
  expect_not "left the player" 'stack=[^ ]*PlayerScreen> '
}

library_walk() { # shows or movies, already inside the room
  expect "library room opened" 'LibraryRoom'  || return 1
  presses Down Down Right Right Left Left Up
  go_zone Down 'zone:tabs ' 5 && presses Right Left Right Left
  go_zone Down 'zone:chips ' 3 && presses Right Right Right Left Left Left Up
  if need "reach the poster grid" Down 'zone:grid ' 8; then
    presses Right Right Down Down Up Left Up Down
    press Info; sleep 1; presses Down Back
    sleep 1
    press Select
    sleep 2
    expect "OK on a poster opens Details" 'stack=[^ ]*DetailsScreen> ' || return 1
    details_walk
    press Back; sleep 1
    expect "Back from Details returns to the library" 'stack=HubScreen> '
  fi
}

# open one music screen over ECP (walk build only), press KEYS, then Back must leave it
open_walk() { # mode screen "keys"
  unwind || true
  STEP=$((STEP+1)); row INFO "open" "open $1 directly" "" ""
  curl -s -m 5 -X POST "$ECP/input?walkOpen=$1" >/dev/null
  sleep 3
  if ! expect "$1 opens $2" "stack=[^ ]*$2> "; then return 1; fi
  for kk in $3; do press "$kk"; done
  press Back; sleep 2
  # MusicView and the big view can take a moment to slide away
  if [ "$(top_screen)" = "$2" ]; then press Back; sleep 2; fi
  expect_not "Back leaves $2" "stack=[^ ]*$2> "
}

# ---------------------------------------------------------------- the paths
run_paths() {

if begin P01 "Room bar: every pill, wrap-around"; then
  unwind
  presses Right Right Right Right Right Right Right Right
  expect "8 Rights wrap to Home" 'screen=HubScreen.*pillIndex:0 '
  press Left
  expect "Left from Home goes to Search" 'screen=HubScreen.*pillIndex:7 '
  presses Right
  expect "Right returns to Home" 'screen=HubScreen.*pillIndex:0 '
  unwind
fi

if begin P02 "Hub * menu opens and closes (nothing selected)"; then
  unwind
  press Info; sleep 1
  expect "* opens the Hearth dialog" 'dialog=StandardMessageDialog:Hearth'
  press Down; press Up; press Back; sleep 1
  expect_not "Back closed the dialog" 'dialog=StandardMessageDialog'
  unwind
fi

if begin P03 "Leave prompt: Stay keeps you in"; then
  unwind
  press Back; sleep 1
  if ! last_stack | grep -q 'dialog=StandardMessageDialog:Leave Hearth'; then press Back; sleep 1; fi
  expect "Back on Home bar shows Leave Hearth?" 'dialog=StandardMessageDialog:Leave Hearth'
  presses Right Left
  press Back; sleep 1
  expect_not "dialog closed" 'dialog=StandardMessageDialog'
  expect "still in the hub" 'stack=HubScreen> '
  unwind
fi

if begin P04 "Home room: rows, hero, options"; then
  goto_room 0
  expect "Home room entered" 'HomeRoom'
  presses Down Down Down Down Down Down Up Up Up Up Up Up Right Right Left Left
  press Info; sleep 1; press Back; sleep 1
  presses Down Right Right Right Right Down Left Left Up Up Up
  sleep 5
  unwind
fi

if begin P05 "Home hero: OK opens Details or the player"; then
  goto_room 0
  presses Up Up Up
  press Select; sleep 3
  t=$(top_screen)
  if [ "$t" = "DetailsScreen" ]; then details_walk
  elif [ "$t" = "PlayerScreen" ]; then play_walk
  else note "hero OK went to $t"; fi
  unwind
fi

if begin P06 "Shows: tabs, chips, grid, options, Details, Back"; then
  goto_room 1
  library_walk
  unwind
fi

if begin P07 "Movies: tabs, chips, grid, options, Details, Back"; then
  goto_room 2
  library_walk
  unwind
fi

if begin P08 "Details to Player: play, pause screen, panels, Back"; then
  goto_room 2
  if need "reach the poster grid" Down 'zone:grid ' 8; then
    press Select; sleep 3
    if expect "Details opened" 'stack=[^ ]*DetailsScreen> '; then
      go_zone Up 'zone:act ' 6
      presses Left Left Left
      press Select
      play_walk
    fi
  fi
  unwind
fi

if begin P09 "Music room: panel, tabs, content, Back"; then
  goto_room 3
  expect "Music room entered" 'MusicRoom'
  presses Down Down Up Up Right Right Right Left Left Down Down Down Up Up Up
  presses Right Right Right Right Right Right Down Down Up Up Left Left Left Left Left
  press Info; sleep 1; press Back
  sleep 2
  unwind
fi

if begin P10 "Music: big view, radio, schedules, Last.fm, request screens"; then
  # each screen is opened directly over ECP (walk build only), walked without pressing anything that plays or saves, then left with Back
  open_walk radio RadioScreen "Down Down Down Up Up Up Right Left"
  open_walk lastfm LastfmScreen "Down Down Up Up"
  open_walk schedules ScheduleScreen "Right Left Down Down Down Down Down Down Down Down Down Up Up Up Up Up Up Up Up Up"
  open_walk big MusicBigView "Down Down Up Up Right Left"
  open_walk cover MusicView "Up Up Down"
  open_walk milk MusicView "Right Left Up Up"
  open_walk hearth MusicView "Up Up Down"
  open_walk request LidarrScreen "Lit_a Lit_b Lit_b Lit_a Down Right Left Up Backspace Backspace Backspace Backspace"
  # the two action tabs in the room itself: Radio and Request open their screens with OK
  goto_room 3
  if go_zone Right 'zone:tabs ' 4; then
    presses Right Right Right Right Right Right
    expect "on the Radio tab" 'MusicRoom.*tab'
    press Select; sleep 2
    expect "OK on the Radio tab opens Radio" 'stack=[^ ]*RadioScreen> '
    press Back; sleep 1
    expect "Back returns to the Music room" 'stack=HubScreen> '
  fi
  unwind
fi

if begin P11 "Requests: every list on the rail, grid, popup (no request sent), filters"; then
  goto_room 4
  expect "Requests room entered" 'RequestsRoom'
  sleep 3
  go_zone Left 'zone:rail ' 4
  go_zone Up 'railIndex:0 ' 8
  for ri in 1 2 3 4 5 6 7; do
    press Down; sleep 2
    presses Right Right Left
    go_zone Left 'zone:rail ' 4
  done
  go_zone Up 'railIndex:2 ' 6
  press Right; sleep 1
  if last_key | grep -q 'zone:grid '; then
    presses Right Down Up Left
    press Select; sleep 2
    expect "OK on a card opens the popup" 'zone:popup'
    presses Right Left Down Up
    press Back; sleep 1
    expect_not "Back closes the popup" 'zone:popup'
    go_zone Up 'zone:bar ' 4 && press Select
    sleep 1
    presses Down Up Back
  fi
  unwind
fi

if begin P12 "Requests: search keyboard, typing, results, popup"; then
  goto_room 4
  sleep 3
  go_zone Left 'zone:rail ' 4
  go_zone Up 'railIndex:0 ' 8
  press Right
  expect "Right on Search opens the keyboard" 'RequestsRoom.*zone:kb '
  presses Down Right Left Up
  presses Lit_d Lit_u Lit_n Lit_e
  sleep 4
  press Right
  if last_key | grep -q 'zone:results '; then
    presses Down Up
    press Select; sleep 2
    expect "OK on a result opens the popup" 'zone:popup'
    press Back; sleep 1
  fi
  presses Left Backspace Backspace Backspace Backspace
  unwind
fi

if begin P13 "Ambiance: moods, mood screen, controls, sleep menu, Back"; then
  goto_room 5
  expect "Ambiance room entered" 'AmbianceRoom'
  presses Right Right Right Left Left Left
  press Select; sleep 4
  t=$(top_screen)
  if [ "$t" = "MoodScreen" ]; then
    presses Right Left Up Select
    sleep 1
    presses Left Right Back
    sleep 1
    press Info; sleep 1; presses Down Back
    sleep 1
    expect "still in the mood" 'MoodScreen'
    press Back; sleep 2
  else note "Ambiance OK went to $t"; fi
  unwind
fi

if begin P14 "Photos: buttons, albums, slideshow, options, Back"; then
  goto_room 6
  expect "Photos room entered" 'PhotosRoom'
  sleep 3
  presses Right Left Down Right Left Up
  go_zone Down 'zone:albums ' 3 && presses Right Left
  press Select; sleep 5
  if [ "$(top_screen)" = "SlideshowScreen" ]; then
    presses Right Right Left Up Select Select Down
    sleep 1
    presses Down Back
    sleep 1
    press Back; sleep 2
  else note "Photos OK went to $(top_screen)"; fi
  unwind
fi

if begin P15 "Search: type, results, empty state, Details"; then
  goto_room 7
  expect "Search room entered" 'SearchRoom'
  presses Lit_t Lit_h Lit_e
  sleep 3
  if last_key | grep -q 'term:the '; then note "ECP letters reached the keyboard"; else note "ECP letters did NOT reach the keyboard (term not 'the')"; fi
  press Right; sleep 1
  presses Down Down Up Left
  presses Backspace Backspace Backspace Lit_z Lit_z Lit_q Lit_x Lit_j Lit_k
  sleep 3
  press Right
  presses Backspace Backspace Backspace Backspace Backspace Backspace
  presses Lit_a Lit_l Lit_i Lit_e Lit_n
  sleep 3
  go_zone Right 'zone:results ' 2
  if last_key | grep -q 'zone:results '; then
    press Select; sleep 3
    if [ "$(top_screen)" = "DetailsScreen" ]; then details_walk; fi
  fi
  unwind
fi

if begin P16 "Media keys outside video (Play, Rewind, Fast forward)"; then
  unwind
  press Play; sleep 3
  presses Rev Fwd
  sleep 6
  unwind
fi

if begin P17 "Idle soak: 30 s on Home with no keys"; then
  goto_room 0
  sleep 30
  press Down
  press Up
  unwind
fi

}

# ---------------------------------------------------------------- run
say "Launching Hearth with the walk trace..."
launch
if ! wait_hub 120; then
  echo
  if [ ! -s "$LOG" ]; then
    echo "STOPPED: the TV sent no log at all on port $LOG_PORT. Close any other Terminal window running 'nc $TV $LOG_PORT' and run the command again."
  elif ! grep -q 'HWALK trace on' "$WLOG" 2>/dev/null; then
    echo "STOPPED: the TV log is coming in, but Hearth never printed the walk trace."
  else
    echo "STOPPED: Hearth never reached the room bar in 120 s."
  fi
  echo "App on screen now: $(curl -s -m 5 "$ECP/query/active-app" | grep -o '<app[^<]*<' | head -1)"
  echo "Last lines of the TV log (send me these):"
  tail -n 25 "$LOG"
  exit 3
fi
say "Hub is up. Walking. (about 30 to 40 minutes; every press is screenshotted. Leave the remote alone until it finishes)"
run_paths

# ---------------------------------------------------------------- report
{
  echo "# Hearth live walk $STAMP"
  echo
  echo "Build commit: ${COMMIT:-n/a}.  Steps pressed: $(awk -F'\t' '$3!="expect" && $3!="unwind" && $3!="note" && $3!="zone"' "$RES" | wc -l | tr -d ' ')"
  echo
  TOTF=$(awk -F'\t' '$4=="FAIL"' "$RES" | wc -l | tr -d ' ')
  TOTW=$(awk -F'\t' '$4=="WARN"' "$RES" | wc -l | tr -d ' ')
  LOGERR=$(grep -cE "$ERRRE" "$LOG" | tr -d ' ')
  echo "**Total: $TOTF FAIL, $TOTW WARN, $LOGERR log error lines.**"
  echo
  echo "| Path | What | Steps | FAIL | WARN | Result |"
  echo "|---|---|---|---|---|---|"
  awk -F'\t' '{id=$1; t[id]=$8; n[id]++; if($4=="FAIL")f[id]++; if($4=="WARN")w[id]++; if(!(id in seen)){seen[id]=1; order[++c]=id}} END{for(i=1;i<=c;i++){id=order[i]; r="PASS"; if(w[id]>0)r="WARN"; if(f[id]>0)r="FAIL"; printf "| %s | %s | %d | %d | %d | %s |\n", id, t[id], n[id], f[id]+0, w[id]+0, r}}' "$RES"
  echo
  echo "## Failures and warnings"
  echo
  awk -F'\t' '$4=="FAIL" || $4=="WARN" {printf "- **%s** %s #%s key %s: %s  \n  state: %s  \n  shot: %s\n", $4, $1, $2, $3, $5, $7, $6}' "$RES"
  echo
  echo "## Log error lines"
  echo
  echo '```'
  grep -nE "$ERRRE" "$LOG" | head -60
  echo '```'
  echo
  echo "## Not tested by this walk"
  echo
  echo "- The screensaver (the TV starts it itself after idle time)."
  echo "- Loading, empty and error states that need the NAS or Plex to be off or slow (only the Search empty state is forced)."
  echo "- Anything that changes your data: Request buttons, Sign out, Cancel request, Watched, Rate. The walk never presses those."
  echo "- Voice, the phone remote page, casting to speakers."
  echo "- Whether an item looks right; the screenshots are for you and me to read."
} > "$OUT/report.md"

{
  echo "<html><head><meta charset=utf-8><title>Hearth walk $STAMP</title><style>body{font-family:sans-serif;background:#111;color:#ddd;margin:20px}td,th{border:1px solid #444;padding:4px 8px;font-size:13px}img{width:320px;margin:2px}.FAIL{color:#f66}.WARN{color:#fc6}.PASS{color:#7c7}</style></head><body><h1>Hearth walk $STAMP</h1>"
  echo "<pre>"; sed -n '1,/^## Failures/p' "$OUT/report.md" | head -60; echo "</pre><h2>Every step</h2><table><tr><th>path</th><th>#</th><th>key</th><th>result</th><th>note</th><th>state</th><th>shot</th></tr>"
  awk -F'\t' '{img=""; if($6!="") img="<a href=\"" $6 "\"><img src=\"" $6 "\"></a>"; printf "<tr><td>%s</td><td>%s</td><td>%s</td><td class=%s>%s</td><td>%s</td><td>%s</td><td>%s</td></tr>\n", $1,$2,$3,$4,$4,$5,$7,img}' "$RES"
  echo "</table></body></html>"
} > "$OUT/report.html"

( cd "$OUTBASE" && zip -qr "hearth-walk-$STAMP.zip" "hearth-walk-$STAMP" -x "*/.curlcfg" ) 2>/dev/null
echo
sed -n '1,/^## Failures/p' "$OUT/report.md" | sed '$d'
echo "Report:  $OUT/report.html"
echo "Bundle:  $OUTBASE/hearth-walk-$STAMP.zip   (drop this file into the chat so I can read the screenshots)"
which open >/dev/null 2>&1 && open "$OUT/report.html" 2>/dev/null
if [ "$TOTF" = "0" ] && [ "$LOGERR" = "0" ]; then exit 0; fi
exit 4
}
