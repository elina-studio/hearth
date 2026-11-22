#!/bin/sh
# Rebuild every Ambiance asset from source. Needs python3 (numpy, Pillow), ffmpeg, node + playwright.
#   sh tools/ambiance/build.sh
set -e
cd "$(dirname "$0")/../.."
T=$(mktemp -d)
python3 tools/ambiance/sounds.py "$T" 60 44100
python3 tools/ambiance/sounds.py "$T" 16 22050 -short
python3 tools/ambiance/fire.py "$T/fire.jpg"
python3 tools/ambiance/art.py "$T/svg"
python3 tools/ambiance/dividers.py "$T/div"
NODE_PATH=${NODE_PATH:-$(npm root -g)} node tools/ambiance/shot.js "$T/div" "$T/png"
NODE_PATH=${NODE_PATH:-$(npm root -g)} node tools/ambiance/shot.js "$T/svg" "$T/png"
python3 tools/ambiance/finish.py "$T" images/amb sounds
rm -rf "$T"
