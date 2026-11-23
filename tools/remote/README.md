# Hearth phone remote

A small web page for the phone, served from the NAS in Docker. It sends keys to the
Roku over ECP and types straight into Hearth's keyboards.

- `http://192.168.254.41:8765` everyday remote (the phone keyboard's own mic works here)
- `https://192.168.254.41:8766` same page with the in-page mic button (accept the
  self-made certificate once). Voice goes to the Wyoming whisper server on :10300.

## Install / update (on the NAS)

    ssh -t Elina@192.168.254.41 "mkdir -p /volume1/docker/hearth-remote && rm -rf /tmp/hearth-dl && mkdir /tmp/hearth-dl && cd /tmp/hearth-dl && curl -sL https://github.com/elina-studio/hearth/archive/refs/heads/claude/hearth-app.tar.gz | tar xz && cp hearth-*/tools/remote/* /volume1/docker/hearth-remote/ && cd /volume1/docker/hearth-remote && sudo /usr/local/bin/docker compose up -d --build && sudo /usr/local/bin/docker logs hearth-remote"

## How text reaches Hearth

`POST http://<tv>:8060/input?hearthText=<text>[&hearthGo=search|request]`

- no `hearthGo`: the focused HearthKeyboard (or an open Roku keyboard dialog) shows the text
- `hearthGo=search`: back to the hub, Search room, text in its keyboard
- `hearthGo=request`: back to the hub, Requests room, Overseerr search for the text

"Type into other apps" sends `Lit_` keypresses instead, for any app's Roku keyboard.

## Lyrics and Last.fm (Music)

- `GET /api/lyrics?artist=&title=&album=&duration=&file=` finds time-coded lyrics: a `.lrc` file next to the song first, then LRCLIB. Cached in `data/lyrics`.
- Last.fm: Hearth sends plays to `POST /api/lastfm/event`; pairing is on the phone at `/lastfm`. The session key stays in `data/lastfm.json`.
  Get an API key and secret (free) at https://www.last.fm/api/account/create, then create `/volume1/docker/hearth-remote/.env` with
  `LASTFM_API_KEY=...` and `LASTFM_API_SECRET=...` and run `sudo docker compose up -d --build`.

## Lining up the TV with the house speakers

"Line up the house" (https page only, it needs the microphone) listens for 5 seconds while the TV and the
speakers play the same song, finds how far apart they are, and moves the TV by that much:
`POST http://<tv>:8060/input?castTrim=<seconds>` (signed). It checks again afterwards and flips direction if the
first move went the wrong way. "Keep checking" repeats every 40 seconds.

## Hearth for browsers (the projector)

The same helper also serves a browser version of Hearth at `/hearth/` (files in `web/`).
It reaches Plex and Overseerr through `/px/plex/...` and `/px/overseerr/...`, where the
helper adds the keys saved in `data/hearth-keys.json` (run `save-keys.sh` first), so the
page never holds a password.

- Open `https://192.168.254.41:8766/hearth/` on the projector (accept the certificate once;
  plain `http://192.168.254.41:8765/hearth/` also works if the browser allows it).
- Ready: Home, Music, Ambiance, Test video. Movies, Shows, Requests, Photos and Search show a
  placeholder until they are ported.
