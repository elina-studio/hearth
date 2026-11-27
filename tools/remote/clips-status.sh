#!/bin/bash
# Run on the Mac (tools/update.sh runs it). Shows what the helper found in the hearth folder and waits, up to
# 15 minutes, while it makes TV copies of clips this TV can't play as they are. Never prints the house key.
# Plain bash 3.2 here, BusyBox sh on the NAS.
NAS="Elina@192.168.254.41"
CTL="-o ControlMaster=auto -o ControlPath=/tmp/hearth-ssh-%r-%h -o ControlPersist=300"
ssh -t $CTL "$NAS" 'sudo -v && K=$(sudo cat /volume1/docker/hearth-remote/data/helper-token 2>/dev/null | tr -d "\r\n")
if [ -z "$K" ]; then echo "Could not read the house key, so the clips were not checked."; exit 0; fi
LAST=""
i=0
while [ $i -lt 90 ]; do
  T=$(curl -s --max-time 10 -H "X-Hearth-Token: $K" "http://127.0.0.1:8765/api/clips?text=1")
  HEAD=$(echo "$T" | head -1)
  BODY=$(echo "$T" | tail -n +2)
  if [ "$BODY" != "$LAST" ]; then echo "$BODY"; echo; LAST="$BODY"; fi
  if [ "$HEAD" = "DONE" ]; then echo "All clips are ready for the TV."; exit 0; fi
  if [ "$HEAD" = "NOFOLDER" ]; then echo "The helper cannot see a hearth folder. Send me the lines above."; exit 0; fi
  if [ "$HEAD" != "WORKING" ]; then echo "The helper did not answer about clips (got: $HEAD). Send me this line."; exit 0; fi
  i=$((i+1))
  sleep 10
done
echo "Still making TV copies after 15 minutes. That is fine: it carries on by itself, and each clip shows on the TV once it is ready."'
