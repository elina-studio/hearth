#!/bin/bash
# Run on the Mac. Prints the one-time links that let a phone or the projector page use the NAS helper.
# The house key is shown only in your own Terminal window; don't paste it anywhere else.
NAS="Elina@192.168.254.41"
KEY=$(ssh -t "$NAS" "sudo cat /volume1/docker/hearth-remote/data/helper-token" 2>/dev/null | tr -d '\r\n ')
[ ${#KEY} -lt 16 ] && { echo "Couldn't read the house key. Is the helper running (new version)?"; exit 1; }
echo
echo "Phone remote (open this on the phone once, it remembers):"
echo "  http://192.168.254.41:8765/?t=$KEY"
echo "Projector page (open once in that browser):"
echo "  http://192.168.254.41:8765/hearth/?t=$KEY"
echo
echo "The TV needs nothing: the helper lets the TV in by its address."
