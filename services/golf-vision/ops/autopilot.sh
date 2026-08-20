#!/bin/bash
# Everything that remains of the 2026-08-19 quality push, with nobody
# watching: wait out the corpus build, train, score, deploy only on a
# measured win, and clean up the course data afterwards — dữ liệu sân
# dùng xong thì xoá.
#
# Every step is idempotent and the whole thing survives a restart: the
# corpus build resumes, training skips itself if its last score exists,
# and the deploy compares scores before touching anything. DISK-STOP is
# the disk guard's voice: "the corpus is as big as this disk allows" —
# it ends the wait instead of resuming the build into the same wall.
set -u
PY=/root/miniconda3/envs/golfseg/bin/python
LOG() { echo "[autopilot $(date '+%F %T')] $*"; }

LOG "autopilot up, waiting on the corpus"
while true; do
  if grep -q "=== ALL DONE" /data/golfseg/corpus-large.log 2>/dev/null; then
    LOG "corpus done"; break
  fi
  if [ -f /data/golfseg/DISK-STOP ]; then
    LOG "disk guard stopped the build — taking the corpus as it stands"
    cd /root/golfseg/golf-vision
    $PY datasets/build_naip_dataset.py --index /data/golfseg/osm-us-large \
        --out /data/golfseg/golfseg-us-large --merge \
        >> /data/golfseg/naip-merge.log 2>&1
    break
  fi
  if ! pgrep -f "corpus[-]large.sh" >/dev/null; then
    LOG "corpus build not running and not done — resuming it"
    setsid nohup /root/golfseg/corpus-large.sh >> /data/golfseg/corpus-large.log 2>&1 < /dev/null &
  fi
  sleep 300
done

train=$(ls /data/golfseg/golfseg-us-large/images/train 2>/dev/null | wc -l)
LOG "corpus: $train training patches"
if [ "$train" -lt 8000 ]; then
  LOG "under 8000 patches — smaller than the old corpus deserves; stopping for a human"
  exit 1
fi

if [ ! -f /data/golfseg/runs/vn-large-s2-l0.5/tta.test.json ]; then
  LOG "training start"
  /root/golfseg/train-large.sh > /data/golfseg/train-large.log 2>&1
  LOG "training done"
fi

$PY /root/golfseg/pick_winner.py > /data/golfseg/autopilot-summary.json 2>> /data/golfseg/autopilot.log
winner=$(python3 -c "import json;d=json.load(open('/data/golfseg/autopilot-summary.json'));print(d.get('deploy') or '')")
if [ -n "$winner" ]; then
  LOG "deploying $winner"
  mkdir -p /root/golfseg/golf-vision/models/vn-large-best
  cp "$winner" /root/golfseg/golf-vision/models/vn-large-best/best.pt
  mkdir -p /etc/systemd/system/golfseg-service.service.d
  cat > /etc/systemd/system/golfseg-service.service.d/checkpoint.conf <<CONF
[Service]
Environment=GOLF_SEG_CHECKPOINT=/root/golfseg/golf-vision/models/vn-large-best/best.pt
CONF
  systemctl daemon-reload && systemctl restart golfseg-service
  sleep 8
  curl -sf 127.0.0.1:8100/health >/dev/null && LOG "service healthy on the new weight" \
    || { LOG "service unhealthy — rolling back"; rm /etc/systemd/system/golfseg-service.service.d/checkpoint.conf; systemctl daemon-reload; systemctl restart golfseg-service; }
else
  LOG "no candidate beat the deployed baseline — nothing deployed"
fi

if [ -f /data/golfseg/autopilot-summary.json ]; then
  LOG "deleting the patch corpus"
  rm -rf /data/golfseg/golfseg-us-large /data/golfseg/pbf
fi
LOG "AUTOPILOT DONE"
