#!/bin/bash
set -euo pipefail
source "$(conda info --base)/etc/profile.d/conda.sh"
conda activate llamafactory

if ! command -v llamafactory-cli >/dev/null 2>&1; then
  echo "Error: 'llamafactory-cli' was not found in the 'llamafactory' env."
  echo "Install LLaMA-Factory into that env first."
  exit 1
fi

: "${model_name_or_path=YOUR_MODEL_PATH}"
: "${template:=qwen2_vl}"
: "${TOTAL_GPUS:=8}"

# Usage: ./lf_serve_cot.sh <num_instances>
# e.g.:  ./lf_serve_cot.sh 4   # start 4 instances
#        ./lf_serve_cot.sh 8   # start 8 instances

if [ $# -lt 1 ]; then
  echo "Usage: $0 <num_instances>"
  exit 1
fi

num_instances=$1
start_port=8192

if [ "$num_instances" -le 0 ]; then
  echo "num_instances must be positive."
  exit 1
fi

if [ "$TOTAL_GPUS" -lt "$num_instances" ]; then
  echo "TOTAL_GPUS ($TOTAL_GPUS) must be >= num_instances ($num_instances)."
  exit 1
fi

if [ $((TOTAL_GPUS % num_instances)) -ne 0 ]; then
  echo "TOTAL_GPUS ($TOTAL_GPUS) must be divisible by num_instances ($num_instances)."
  exit 1
fi

cards_per_instance=$((TOTAL_GPUS / num_instances))

cleanup() {
  jobs -p | xargs -r kill 2>/dev/null || true
}
trap cleanup EXIT INT TERM

for i in $(seq 0 $((num_instances-1))); do
  start_card=$((i * cards_per_instance))
  end_card=$((start_card + cards_per_instance - 1))
  port=$((start_port + i))

  devices=$(seq -s, $start_card $end_card)

  echo "Start Instance $i: Use Devices: $devices, Port: $port"

  CUDA_VISIBLE_DEVICES=$devices API_VERBOSE=0 \
  API_PORT=$port \
  llamafactory-cli api \
    --model_name_or_path $model_name_or_path \
    --template $template \
    --infer_backend vllm \
    --image_max_pixels 262144 \
    --vllm_maxlen 65536 \
    --trust_remote_code true &
done

wait

# --vllm_maxlen 16384
# Controls vllm kvcache max tokens (input+output). At current resolution,
# 1920x1080 after smart resize is about 1248 tokens.
# Keep prompt length in check, otherwise you may need tensor parallelism to avoid OOM.
# Can be ignored if you have 80GB VRAM.
