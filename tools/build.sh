#!/bin/bash
# Safe build: precheck, then bsc; any error stops it and no stale zip can ship.
# Usage: BSC=/path/to/bsc bash tools/build.sh
set -e
cd "$(dirname "$0")/.."
python3 tools/precheck.py
rm -f out/hearth.zip
OUT=$(${BSC:-bsc} --project bsconfig.json 2>&1) || { echo "$OUT"; echo "BUILD FAILED"; exit 1; }
echo "$OUT" | grep -iE "error" && { echo "BUILD FAILED"; exit 1; }
[ -f out/hearth.zip ] && echo "built out/hearth.zip" || { echo "no zip produced"; exit 1; }
