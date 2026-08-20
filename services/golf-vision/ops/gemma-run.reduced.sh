#!/bin/bash
set -a; . /root/golfseg/.gemma.env; set +a
# vLLM gemma at 0.80 GPU util (was 0.90), to free ~8GB for a one-off GolfSeg
# training run. Identical to the original in every other respect — generated
# from runlike of the live container, only the last number changed.
docker run --name=gemma4-awq-vllm --hostname=93792c982a27 \
  --volume /data/huggingface:/root/.cache/huggingface \
  --env=HUGGING_FACE_HUB_TOKEN=${HUGGING_FACE_HUB_TOKEN} \
  --network=bridge --workdir=/vllm-workspace -p 8000:8000 \
  --restart=always --runtime=nvidia --detach=true vllm/vllm-openai:gemma4 \
  --host 0.0.0.0 --model google/gemma-4-26B-A4B-it \
  --served-model-name google/gemma-4-26B-A4B-it --dtype float16 \
  --enable-auto-tool-choice --tool-call-parser gemma4 --reasoning-parser gemma4 \
  --api-key ${VLLM_API_KEY} \
  --download-dir /root/.cache/huggingface --gpu-memory-utilization 0.80
