# Hearth phone remote

A small web page for the phone, served from the NAS in Docker. It sends keys to the
Roku over ECP and types straight into Hearth's keyboards.

- `http://192.168.254.41:8765` everyday remote (the phone keyboard's own mic works here)
- `https://192.168.254.41:8766` same page with the in-page mic button (accept the
  self-made certificate once). Voice goes to the Wyoming whisper server on :10300.

## Install / update (on the NAS)

    ssh -t Elina@192.168.254.41 "mkdir -p /volume1/docker/hearth-remote && rm -rf /tmp/hearth-dl && mkdir /tmp/hearth-dl && cd /tmp/hearth-dl && curl -sL https://github.com/elina-studio/hearth/archive/refs/heads/claude/project-thread-xqh7n7.tar.gz | tar xz && cp hearth-*/tools/remote/* /volume1/docker/hearth-remote/ && cd /volume1/docker/hearth-remote && sudo /usr/local/bin/docker compose up -d --build && sudo /usr/local/bin/docker logs hearth-remote"

## How text reaches Hearth

`POST http://<tv>:8060/input?hearthText=<text>[&hearthGo=search|request]`

- no `hearthGo`: the focused HearthKeyboard (or an open Roku keyboard dialog) shows the text
- `hearthGo=search`: back to the hub, Search room, text in its keyboard
- `hearthGo=request`: back to the hub, Requests room, Overseerr search for the text

"Type into other apps" sends `Lit_` keypresses instead, for any app's Roku keyboard.

## Lining up the TV with the house speakers

"Line up the house" (https page only, it needs the microphone) listens for 5 seconds while the TV and the
speakers play the same song, finds how far apart they are, and moves the TV by that much:
`POST http://<tv>:8060/input?castTrim=<seconds>` (signed). It checks again afterwards and flips direction if the
first move went the wrong way. "Keep checking" repeats every 40 seconds.
