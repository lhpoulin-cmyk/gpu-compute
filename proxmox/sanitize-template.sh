#!/usr/bin/env bash
set -Eeuo pipefail

# Guarded: only runs inside a VM named tpl-cuda-compute-ubuntu2604-* or with --force
hostname=$(hostname)
[[ "$hostname" == tpl-cuda-compute-ubuntu2604-* ]] || {
  echo "this script is for template VM 9320 candidates only; hostname: $hostname" >&2
  echo "use --force only after confirming this is the candidate VM, not VM 320" >&2
  [[ "${1:-}" == "--force" ]] || exit 65
}

echo "sanitizing template candidate..."

# Remove instance identity
truncate -s 0 /etc/machine-id
rm -f /var/lib/dbus/machine-id
ln -sf /etc/machine-id /var/lib/dbus/machine-id

# Remove SSH host keys (regenerated at first boot)
rm -f /etc/ssh/ssh_host_*

# Remove cloud-init instance data
rm -rf /var/lib/cloud/instances /var/lib/cloud/instance

# Clear logs
find /var/log -type f -exec truncate -s 0 {} +

# Remove appliance instance state (but preserve workspace structure)
rm -f /srv/gpu-compute/config/active-hardware-profile.yaml
rm -f /srv/gpu-compute/config/instance-state.yaml
find /srv/gpu-compute/evidence -mindepth 1 -delete 2>/dev/null || true
find /srv/gpu-compute/jobs -mindepth 1 -delete 2>/dev/null || true
find /srv/gpu-compute/logs -mindepth 1 -delete 2>/dev/null || true
find /srv/gpu-compute/tmp -mindepth 1 -delete 2>/dev/null || true

# Keep BUILD: it identifies the appliance software build and is required by smoke tests.
# Keep the CUDA toolkit and pinned llama.cpp/Ollama software, but leave Ollama disabled.
systemctl disable --now ollama.service >/dev/null 2>&1 || true

echo "sanitized; shut down and run: qm template 9320"
