#!/bin/bash
# Run on the Mac. One command: updates the NAS helper, then prints your links and checks the lock works.
#   bash <(curl -sL https://raw.githubusercontent.com/elina-studio/hearth/<commit>/tools/remote/deploy.sh)
# It asks for the NAS ssh password and the sudo password once. The house key is shown only in this Terminal window.
NAS="Elina@192.168.254.41"
BRANCH=${HEARTH_BRANCH:-claude/project-thread-y2pdyc}
# HEARTH_REF (a commit) installs exactly that commit's helper; without it, the newest of the branch
REF=refs/heads/$BRANCH
[ -n "$HEARTH_REF" ] && REF=$HEARTH_REF
CTL="-o ControlMaster=auto -o ControlPath=/tmp/hearth-ssh-%r-%h -o ControlPersist=300"
R() { ssh -t $CTL "$NAS" "$@"; }

echo "1/4 Signing in to the NAS (ssh password, then the sudo password)..."
R "sudo -v" || exit 1

echo "2/4 Updating the helper (about a minute)..."
R "mkdir -p /volume1/docker/hearth-remote && rm -rf /tmp/hearth-dl && mkdir /tmp/hearth-dl && cd /tmp/hearth-dl && curl -sL https://github.com/elina-studio/hearth/archive/$REF.tar.gz | tar xz && cp -r hearth-*/tools/remote/. /volume1/docker/hearth-remote/ && rm -rf /volume1/docker/hearth-remote/viz && mkdir -p /volume1/docker/hearth-remote/viz && cp hearth-*/tools/viz/viz.js hearth-*/tools/viz/page.html hearth-*/tools/viz/looks.json hearth-*/tools/viz/package.json hearth-*/tools/viz/package-lock.json /volume1/docker/hearth-remote/viz/ && cd /volume1/docker/hearth-remote && sudo /usr/local/bin/docker compose up -d --build >/tmp/hearth-build.log 2>&1; echo build exit code \$?; tail -3 /tmp/hearth-build.log" | tee /tmp/hearth-deploy.out
# the old helper keeps answering when a rebuild fails, so check the rebuild itself, not only that something answers
grep -q "build exit code 0" /tmp/hearth-deploy.out || { echo "The helper did NOT update (the rebuild failed, the lines above say why). The old helper is still running."; exit 3; }

echo "3/4 Waiting for the helper..."
for i in $(seq 1 30); do
  C=$(curl -s -o /dev/null -w "%{http_code}" --max-time 2 http://192.168.254.41:8765/api/keys)
  [ "$C" = "401" ] && break
  sleep 2
done
if [ "$C" != "401" ]; then echo "The lock did not come up (got '$C'). Tell me and paste the lines above."; exit 1; fi
echo "   Locked: the keys page now says 401 to strangers."

echo "4/4 Checking the house key (if it asks for the sudo password, type it and press Enter; nothing shows as you type)..."
# one NAS session does it all: a second ssh that only hands the key back comes up empty on this NAS
R 'K=$(sudo cat /volume1/docker/hearth-remote/data/helper-token 2>/dev/null | tr -d "\r\n"); if [ -z "$K" ]; then echo "   Could not read the house key (the helper itself is fine)."; exit 0; fi; C=$(curl -s -o /dev/null -w "%{http_code}" -H "X-Hearth-Token: $K" http://127.0.0.1:8765/api/keys); echo "   With the key: $C (200 is right)."; echo; echo "Save these two links in 1Password (they are your key; do not paste them anywhere else):"; echo "  Phone remote:    http://192.168.254.41:8765/?t=$K"; echo "  Projector page:  http://192.168.254.41:8765/hearth/?t=$K"'
echo
echo "Open each once on its device. The TV needs nothing."
