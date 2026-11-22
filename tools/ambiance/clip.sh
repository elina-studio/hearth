#!/bin/sh
# Turn a phone video into a Hearth ambiance loop.
#   sh tools/ambiance/clip.sh input.mov <hearth|rain|fireflies|lightsout> [start_s] [length_s]
# Writes videos/<mood>.mp4 (1280x720 H.264, AAC, seamless loop: the last second crossfades
# into the first), images/amb/col-<mood>.jpg (760x930 still for the room column) and
# images/amb/full-<mood>.jpg (first frame, shown while the video starts).
set -e
IN="$1"; MOOD="$2"; SS="${3:-0}"; LEN="${4:-24}"; XF=1.5
cd "$(dirname "$0")/../.."
mkdir -p videos
T=$(mktemp -d)
# 1. cut LEN+XF seconds, scale/crop to fill 1280x720, 30 fps, no rotation surprises
ffmpeg -y -loglevel error -ss "$SS" -i "$IN" -t "$(echo "$LEN + $XF" | bc)" \
  -vf "scale=1280:720:force_original_aspect_ratio=increase,crop=1280:720,fps=30,format=yuv420p" \
  -c:v libx264 -crf 16 -preset fast -c:a aac -ar 48000 -ac 2 "$T/cut.mp4"
HAS_AUDIO=$(ffprobe -v error -select_streams a -show_entries stream=index -of csv=p=0 "$T/cut.mp4" | head -1)
# 2. loop: blend the extra tail over the head so frame LEN runs straight into frame 0
if [ -n "$HAS_AUDIO" ]; then
  ffmpeg -y -loglevel error -i "$T/cut.mp4" -filter_complex "\
[0:v]split[v1][v2];[v1]trim=0:$LEN,setpts=PTS-STARTPTS[body];\
[v2]trim=$LEN:$(echo "$LEN + $XF" | bc),setpts=PTS-STARTPTS[tail];\
[body][tail]overlay=enable='lte(t,$XF)':eof_action=pass[ov];\
[0:a]asplit[a1][a2];[a1]atrim=0:$LEN,asetpts=PTS-STARTPTS[ab];[a2]atrim=$LEN,asetpts=PTS-STARTPTS,afade=t=out:d=$XF[at];\
[ab]afade=t=in:d=$XF[abf];[abf][at]amix=inputs=2:duration=first:normalize=0[a]" \
    -map "[ov]" -map "[a]" -c:v libx264 -profile:v high -level 4.0 -b:v 1800k -maxrate 2500k -bufsize 4000k -g 60 \
    -c:a aac -b:a 128k -movflags +faststart "videos/$MOOD.mp4"
else
  case "$MOOD" in hearth|lightsout) S=fire;; rain) S=rain;; *) S=night;; esac
  ffmpeg -y -loglevel error -i "$T/cut.mp4" -stream_loop -1 -i "sounds/$S.mp3" -filter_complex "\
[0:v]split[v1][v2];[v1]trim=0:$LEN,setpts=PTS-STARTPTS[body];\
[v2]trim=$LEN:$(echo "$LEN + $XF" | bc),setpts=PTS-STARTPTS[tail];\
[body][tail]overlay=enable='lte(t,$XF)':eof_action=pass[ov]" \
    -map "[ov]" -map 1:a -t "$LEN" -c:v libx264 -profile:v high -level 4.0 -b:v 1800k -maxrate 2500k -bufsize 4000k -g 60 \
    -c:a aac -b:a 128k -movflags +faststart "videos/$MOOD.mp4"
fi
# 3. column still from the middle of the loop
ffmpeg -y -loglevel error -ss "$(echo "$LEN / 2" | bc)" -i "videos/$MOOD.mp4" -frames:v 1 \
  -vf "scale=-2:930,crop=760:930" -q:v 3 "images/amb/col-$MOOD.jpg"
# full-screen still, shown while the video buffers (first frame, so the fade-in matches)
ffmpeg -y -loglevel error -i "videos/$MOOD.mp4" -frames:v 1 -q:v 4 "images/amb/full-$MOOD.jpg"
rm -rf "$T"
ls -la "videos/$MOOD.mp4" "images/amb/col-$MOOD.jpg" "images/amb/full-$MOOD.jpg"
