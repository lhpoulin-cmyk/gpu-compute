#!/usr/bin/env bash
set -Eeuo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$script_dir/profile-lib.sh"

profile= dry_run=false template_mode=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile)       profile=${2:?}; shift 2 ;;
    --dry-run)       dry_run=true; shift ;;
    --template-mode) template_mode=true; shift ;;
    *) echo "usage: install-profile.sh --profile FILE [--dry-run] [--template-mode]" >&2; exit 64 ;;
  esac
done

[[ -r "$profile" ]] || { echo "profile required" >&2; exit 66; }

profile_id=$(yaml_value "$profile" profile id)
cuda_pkg=$(yaml_value "$profile" cuda toolkit_package)
cuda_version=$(yaml_value "$profile" cuda pinned_version)
min_driver=$(yaml_value "$profile" cuda minimum_driver)
driver_pkg=$(yaml_value "$profile" cuda driver_package)
expected_pci=$(yaml_value "$profile" device expected_pci_id)

for value in "$profile_id" "$cuda_pkg" "$cuda_version" "$min_driver" "$driver_pkg" "$expected_pci"; do
  [[ -n "$value" ]] || { echo "incomplete hardware profile" >&2; exit 65; }
done

echo "# profile: $profile_id"
echo "# CUDA toolkit: $cuda_pkg ($cuda_version)"
echo "# NVIDIA driver package: $driver_pkg; acceptance minimum: $min_driver"
echo "# expected GPU PCI ID: $expected_pci"

if $dry_run; then
  echo "dry-run: would install active hardware profile, blacklist nouveau, install NVIDIA open driver, and enable Ollama"
  $template_mode && echo "dry-run: template-mode would skip driver activation and Ollama enablement"
  exit 0
fi

cp "$profile" /srv/cuda-compute/config/active-hardware-profile.yaml
echo "active-hardware-profile.yaml installed"

if $template_mode; then
  echo "template-mode: NVIDIA driver activation and Ollama service enablement deferred"
  exit 0
fi

cat > /etc/modprobe.d/blacklist-nouveau.conf <<'EOF_NOUVEAU'
blacklist nouveau
options nouveau modeset=0
EOF_NOUVEAU

if ! lspci -nn | grep -qi "\[$expected_pci\]"; then
  echo "expected NVIDIA PCI device $expected_pci is not visible in the guest" >&2
  exit 69
fi

apt-get update -q
apt-get install -y --no-install-recommends "$driver_pkg"
update-initramfs -u

if systemctl list-unit-files ollama.service >/dev/null 2>&1; then
  systemctl enable ollama.service >/dev/null
fi

echo "profile installed; reboot required before CUDA acceptance"
echo "After reboot: verify nvidia-smi, llama-cli --list-devices, then run smoke and acceptance tests"
