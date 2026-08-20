#!/bin/bash
# Tier-0 measurement matrix: what does TTA and ensembling buy, on val (to
# choose) and test (to report). VRAM-capped so vLLM is untouchable.
set -u
cd /root/golfseg/golf-vision
PY=/root/miniconda3/envs/golfseg/bin/python
export PYTORCH_CUDA_ALLOC_CONF=max_split_size_mb:512
NAIP=models/naip-v3/best.pt
UNET=/root/golfseg/runs/unet-r34-v2/best.pt
OUT=/root/golfseg/tier0
mkdir -p $OUT
run() {
  name=$1; split=$2; shift 2
  echo "=== $name ($split) $(date +%H:%M:%S)"
  $PY evaluation/evaluate_checkpoint.py --data /root/golfseg/data \
     --split $split --out $OUT/$name.$split.json "$@" 2>&1 | tail -14
}
for split in val test; do
  run baseline      $split --checkpoint $NAIP
  run tta           $split --checkpoint $NAIP --tta
  run ens2          $split --checkpoint $NAIP $UNET
  run ens2-tta      $split --checkpoint $NAIP $UNET --tta
done
echo "ALL DONE $(date +%H:%M:%S)"
