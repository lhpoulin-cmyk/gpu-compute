#!/usr/bin/env bash
set -Eeuo pipefail

apply=false operator= template_mode=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)      apply=false; shift ;;
    --apply)        apply=true; shift ;;
    --operator)     operator=${2:?}; shift 2 ;;
    --template-mode) template_mode=true; shift ;;
    *) echo "usage: workspace.sh [--dry-run|--apply] [--operator USER] [--template-mode]" >&2; exit 64 ;;
  esac
done

workspace=/srv/cuda-compute
model_base=/mnt/models

dirs=(
  "$workspace/evidence"
  "$workspace/jobs"
  "$workspace/logs"
  "$workspace/scratch"
  "$workspace/tmp"
)

if ! $template_mode; then
  dirs+=(
    "$model_base/library"
    "$model_base/work"
    "$model_base/cache"
    "$model_base/output"
  )
fi

echo "# workspace: $workspace"
if $template_mode; then
  echo "# template mode: model storage intentionally absent"
else
  echo "# model storage: $model_base"
fi
for d in "${dirs[@]}"; do echo "# mkdir -p $d"; done

$apply || { echo "dry-run: workspace not modified"; exit 0; }

if ! $template_mode; then
  findmnt -M "$model_base" -n >/dev/null 2>&1 || {
    echo "ERROR: /mnt/models is not mounted; refusing to create model paths on root filesystem" >&2
    exit 69
  }
fi

for d in "${dirs[@]}"; do
  mkdir -p "$d"
  echo "created: $d"
done

if [[ -n "$operator" ]]; then
  chown -R "$operator" "$workspace/evidence" "$workspace/jobs" "$workspace/scratch" "$workspace/tmp"
fi

if ! $template_mode; then
  mkdir -p /etc/systemd/system/ollama.service.d
  cat > /etc/systemd/system/ollama.service.d/override.conf <<'EOO'
[Service]
Environment="OLLAMA_MODELS=/mnt/models/library"
Environment="OLLAMA_HOST=127.0.0.1:11434"
Environment="CUDA_VISIBLE_DEVICES=0"
EOO
  systemctl daemon-reload
  echo "ollama service override written"
fi
