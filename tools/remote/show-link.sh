#!/bin/bash
# Run on the Mac. Prints the one-time links that let a phone or the projector page use the NAS helper.
# The house key is shown only in your own Terminal window; don't paste it anywhere else.
NAS="Elina@192.168.254.41"
echo "(if it asks for the NAS password, type it and press Enter; nothing shows as you type)"
KEY=$(ssh -t "$NAS" "sudo cat /volume1/docker/hearth-remote/data/helper-token" | tr -d '\r' | grep -oE '[0-9a-f]{48}' | head -1)
[ ${#KEY} -lt 48 ] && { echo "Couldn't read the house key. Is the helper running (new version)?"; exit 1; }
echo
echo "Phone remote (open this on the phone once, it remembers):"
echo "  http://192.168.254.41:8765/?t=$KEY"
echo "Projector page (open once in that browser):"
echo "  http://192.168.254.41:8765/hearth/?t=$KEY"
echo
echo "The TV needs nothing: the helper lets the TV in by its address."
