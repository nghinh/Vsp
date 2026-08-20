#!/bin/bash
# The corpus expansion, end to end: every mapped course in 28 states from
# Geofabrik, then NAIP patches for all of them from Planetary Computer,
# six fetch shards at a time, merged at the end. The PBF downloads are
# deleted as soon as discovery is done — dữ liệu sân dùng xong thì xoá.
set -u
cd /root/golfseg/golf-vision
PY=/root/miniconda3/envs/golfseg/bin/python
IDX=/data/golfseg/osm-us-large
OUT=/data/golfseg/golfseg-us-large

echo "=== discovery start $(date)"
$PY datasets/discover_from_pbf.py --out $IDX --pbf-dir /data/golfseg/pbf \
    --limit 4000 --per-state 300
echo "=== discovery done $(date)"
rm -rf /data/golfseg/pbf
echo "=== pbf deleted $(date)"

echo "=== naip build start $(date)"
for shard in 0 1 2 3 4 5; do
  $PY datasets/build_naip_dataset.py --index $IDX --out $OUT \
      --shard $shard/6 --resume > /data/golfseg/naip-large-shard$shard.log 2>&1 &
done
wait
echo "=== shards done $(date)"
$PY datasets/build_naip_dataset.py --index $IDX --out $OUT --merge
echo "=== ALL DONE $(date)"
