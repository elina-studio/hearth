#!/bin/bash
# THE one command for this build: updates the NAS helper (Discover "New releases" needs it), then puts every key back
# (Sonarr, Radarr, Lidarr, Overseerr, Bazarr, Plex and Home Assistant for the weather) on the NAS backup and the TV.
#   bash <(curl -sL https://raw.githubusercontent.com/elina-studio/hearth/<commit>/tools/remote/setup-all.sh) <commit>
# Open Hearth on the TV first (it only takes keys while the app is running). Asks for the NAS passwords as it goes.
SHA=${1:?need the commit}
BASE=https://raw.githubusercontent.com/elina-studio/hearth/$SHA/tools/remote
export HEARTH_BRANCH=${HEARTH_BRANCH:-claude/project-thread-dcn6uh}
echo "=== Part 1: update the helper ==="
bash <(curl -sL "$BASE/deploy.sh") || { echo "Helper update failed, keys not touched."; exit 1; }
echo
echo "=== Part 2: put every key back, weather included ==="
bash <(curl -sL "$BASE/sync-keys.sh") || exit 1
echo
echo "All done. Reopen Hearth: weather shows top right on Home."
