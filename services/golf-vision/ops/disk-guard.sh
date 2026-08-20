#!/bin/bash
# If the corpus build pushes /data under 12 GB free, stop the build and
# leave a marker saying so. The autopilot reads the marker as "the corpus
# is as big as this disk allows" and moves on to training with what
# exists, rather than resuming the build into the same wall forever.
while true; do
  free_kb=$(df --output=avail /data | tail -1 | tr -d " ")
  if [ "$free_kb" -lt 12582912 ]; then
    echo "$(date) /data under 12GB — stopping the corpus build, leaving DISK-STOP"
    touch /data/golfseg/DISK-STOP
    pkill -f "build_naip[_]dataset"
    pkill -f "corpus[-]large.sh"
    exit 0
  fi
  sleep 120
done
