#!/usr/bin/env bash
# Curious-VLA: Two-stage SFT Training
# Edit sft/sft_stage1.yaml and sft/sft_stage2.yaml before running.
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$(conda info --base)/etc/profile.d/conda.sh"
conda activate llamafactory
cd "$PROJECT_ROOT"

if ! command -v llamafactory-cli >/dev/null 2>&1; then
    echo "Error: 'llamafactory-cli' was not found in the 'llamafactory' env." >&2
    echo "Install LLaMA-Factory into that env first, then rerun this script." >&2
    exit 1
fi

# stage1 warmup
llamafactory-cli train sft/sft_stage1.yaml

# stage2
llamafactory-cli train sft/sft_stage2.yaml
