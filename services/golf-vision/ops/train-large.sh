#!/bin/bash
# The retrain, staged: pretrain once on the large American corpus, then
# fine-tune on Vietnam 3 seeds x {lovasz off, on}, then score every
# fine-tune with TTA on the held-out test courses — the same asking path
# the service uses, so the number is what will be served.
#
# VRAM discipline as in FINDINGS §9: hard fraction cap, vLLM untouched.
set -u
cd /root/golfseg/golf-vision
PY=/root/miniconda3/envs/golfseg/bin/python
US=/data/golfseg/golfseg-us-large
VN=/root/golfseg/data
RUNS=/data/golfseg/runs
CAP=0.11

echo "=== pretrain start $(date)"
$PY training/train.py --data $US --out $RUNS/naip-large-pretrain \
    --provider smp --model-name resnet34 --epochs 16 --batch 12 \
    --workers 8 --vram-fraction $CAP --seed 0 \
    --select-on green 2>&1 | tail -30
echo "=== pretrain done $(date)"

for seed in 0 1 2; do
  for lovasz in 0 0.5; do
    tag="s${seed}-l${lovasz}"
    echo "=== finetune $tag start $(date)"
    $PY training/train.py --data $VN --out $RUNS/vn-large-$tag \
        --provider smp --model-name resnet34 --epochs 40 --batch 8 \
        --workers 8 --vram-fraction $CAP --seed $seed \
        --lovasz-weight $lovasz \
        --init-from $RUNS/naip-large-pretrain/best.pt \
        --select-on green 2>&1 | tail -6
    echo "=== eval $tag $(date)"
    $PY evaluation/evaluate_checkpoint.py --data $VN --split test --tta \
        --checkpoint $RUNS/vn-large-$tag/best.pt \
        --out $RUNS/vn-large-$tag/tta.test.json 2>&1 | tail -14
  done
done
echo "=== TRAINING ALL DONE $(date)"
