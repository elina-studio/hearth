#!/bin/bash
# THE one Mac command for a Hearth build: updates the NAS helper (and through it the NucBox renderer),
# puts the keys back, then installs the build on the TV. Hearth open on the TV; download the build zip first.
#   bash <(curl -sL https://raw.githubusercontent.com/elina-studio/hearth/<commit>/tools/update.sh) <commit> <build number>
# Asks for the NAS passwords and the TV developer password as it goes. Plain bash 3.2.
SHA=${1:?need the commit}
N=${2:?need the build number}
ZIP="$HOME/Downloads/hearth-build-$N.zip"
[ -f "$ZIP" ] || { echo "Download hearth-build-$N.zip from the chat into Downloads first (looked for $ZIP)."; exit 1; }
# the helper is installed from this same commit, so it always matches the build going on the TV
export HEARTH_REF=$SHA
bash <(curl -sL "https://raw.githubusercontent.com/elina-studio/hearth/$SHA/tools/viz/setup-viz.sh") "$SHA" || exit 1
echo
echo "=== Your Ambiance clips (the hearth folder on the NAS) ==="
bash <(curl -sL "https://raw.githubusercontent.com/elina-studio/hearth/$SHA/tools/remote/clips-status.sh")
echo
echo "=== The TV: installing build $N ==="
bash <(curl -sL "https://raw.githubusercontent.com/elina-studio/hearth/$SHA/tools/sideload.sh") "$ZIP"
