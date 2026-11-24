#!/bin/bash
# Run on the Mac. One command: updates the NAS helper, then prints your links and checks the lock works.
#   bash <(curl -sL https://raw.githubusercontent.com/elina-studio/hearth/<commit>/tools/remote/deploy.sh)
# It asks for the NAS ssh password and the sudo password once. The house key is shown only in this Terminal window.
NAS="Elina@192.168.254.41"
BRANCH=${HEARTH_BRANCH:-claude/project-thread-y2pdyc}
CTL="-o ControlMaster=auto -o ControlPath=/tmp/hearth-ssh-%r-%h -o ControlPersist=300"
R() { ssh -t $CTL "$NAS" "$@"; }

echo "1/4 Signing in to the NAS (ssh password, then the sudo password)..."
R "sudo -v" || exit 1

echo "2/4 Updating the helper (about a minute)..."
R "mkdir -p /volume1/docker/hearth-remote && rm -rf /tmp/hearth-dl && mkdir /tmp/hearth-dl && cd /tmp/hearth-dl && curl -sL https://github.com/elina-studio/hearth/archive/refs/heads/$BRANCH.tar.gz | tar xz && cp -r hearth-*/tools/remote/. /volume1/docker/hearth-remote/ && cd /volume1/docker/hearth-remote && sudo /usr/local/bin/docker compose up -d --build >/tmp/hearth-build.log 2>&1; echo build exit code \$?; tail -3 /tmp/hearth-build.log" || exit 1

echo "3/4 Waiting for the helper..."
for i in $(seq 1 30); do
  C=$(curl -s -o /dev/null -w "%{http_code}" --max-time 2 http://192.168.254.41:8765/api/keys)
  [ "$C" = "401" ] && break
  sleep 2
done
if [ "$C" != "401" ]; then echo "The lock did not come up (got '$C'). Tell me and paste the lines above."; exit 1; fi
echo "   Locked: the keys page now says 401 to strangers."

echo "4/4 Reading your house key..."
KEY=$(ssh -t $CTL "$NAS" "sudo cat /volume1/docker/hearth-remote/data/helper-token" 2>/dev/null | tr -d '\r\n ')
[ ${#KEY} -lt 16 ] && { echo "Couldn't read the house key. Tell me."; exit 1; }
C2=$(curl -s -o /dev/null -w "%{http_code}" -H "X-Hearth-Token: $KEY" http://192.168.254.41:8765/api/keys)
echo "   With the key: $C2 (200 is right)."
echo
echo "Save these two links in 1Password (they are your key; don't paste them anywhere else):"
echo "  Phone remote:    http://192.168.254.41:8765/?t=$KEY"
echo "  Projector page:  http://192.168.254.41:8765/hearth/?t=$KEY"
echo
echo "Open each once on its device. The TV needs nothing."
