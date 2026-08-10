#!/usr/bin/env bash
set -Eeuo pipefail

apply=false operator= template_mode=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) apply=false; shift ;;
    --apply) apply=true; shift ;;
    --operator) operator=${2:?}; shift 2 ;;
    --template-mode) template_mode=true; shift ;;
    *) echo "usage: workspace.sh [--dry-run|--apply] [--operator USER] [--template-mode]" >&2; exit 64 ;;
  esac
done

workspace=/srv/gpu-compute
model_base=/mnt/models

dirs=("$workspace/evidence" "$workspace/jobs" "$workspace/logs" "$workspace/scratch" "$workspace/tmp")
if ! $template_mode; then
  dirs+=("$model_base/library" "$model_base/work" "$model_base/cache" "$model_base/output")
fi

echo "# workspace: $workspace"
$template_mode && echo "# template mode: model storage intentionally absent" || echo "# model storage: $model_base"
for d in "${dirs[@]}"; do echo "# mkdir -p $d"; done

$apply || { echo "dry-run: workspace not modified"; exit 0; }
[[ $EUID -eq 0 ]] || { echo "apply requires root" >&2; exit 77; }

if ! $template_mode; then
  findmnt -M "$model_base" -n >/dev/null 2>&1 || {
    echo "ERROR: /mnt/models is not mounted; refusing to create model paths on root filesystem" >&2
    exit 69
  }
fi

for d in "${dirs[@]}"; do
  mkdir -p "$d"
done

if [[ -n "$operator" ]]; then
  id "$operator" >/dev/null 2>&1 || { echo "operator user not found: $operator" >&2; exit 69; }
  chown -R "$operator:$operator" "$workspace/evidence" "$workspace/jobs" "$workspace/scratch" "$workspace/tmp"
  if ! $template_mode; then
    chown -R "$operator:$operator" "$model_base/work" "$model_base/cache" "$model_base/output"
  fi
fi

if ! $template_mode; then
  mkdir -p /etc/systemd/system/ollama.service.d
  cat > /etc/systemd/system/ollama.service.d/override.conf <<'EOF'
[Service]
Environment="OLLAMA_MODELS=/mnt/models/library"
Environment="OLLAMA_HOST=127.0.0.1:11434"
Environment="CUDA_VISIBLE_DEVICES=0"
EOF
  systemctl daemon-reload
fi

echo "workspace prepared"
