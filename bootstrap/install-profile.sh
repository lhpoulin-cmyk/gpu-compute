#!/usr/bin/env bash
set -Eeuo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$script_dir/profile-lib.sh"

profile= dry_run=false template_mode=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile) profile=${2:?}; shift 2 ;;
    --dry-run) dry_run=true; shift ;;
    --template-mode) template_mode=true; shift ;;
    *) echo "usage: install-profile.sh --profile FILE [--dry-run] [--template-mode]" >&2; exit 64 ;;
  esac
done

[[ -r "$profile" ]] || { echo "profile required" >&2; exit 66; }
profile_id=$(yaml_value "$profile" profile id)
stack=$(yaml_value "$profile" stack kind)
expected_pci=$(yaml_value "$profile" device expected_pci_id)
expected_driver=$(yaml_value "$profile" device expected_kernel_driver)

[[ -n "$profile_id" && -n "$stack" ]] || { echo "incomplete hardware profile" >&2; exit 65; }

echo "# profile: $profile_id"
echo "# stack: $stack"
$template_mode && echo "# template mode: active hardware profile is not installed"

if $dry_run; then
  echo "dry-run: would install active profile and instance-specific kernel/service configuration"
  exit 0
fi

[[ $EUID -eq 0 ]] || { echo "apply requires root" >&2; exit 77; }
if $template_mode; then
  echo "template-mode: no active hardware profile installed"
  exit 0
fi

[[ -n "$expected_pci" && -n "$expected_driver" ]] || {
  echo "deployed hardware profile must declare expected PCI ID and guest driver" >&2
  exit 65
}
lspci -nn | grep -Fqi "[$expected_pci]" || {
  echo "expected GPU PCI ID $expected_pci is not visible in the guest" >&2
  exit 69
}

install -d -m 0755 /srv/gpu-compute/config
cp "$profile" /srv/gpu-compute/config/active-hardware-profile.yaml
chmod 0644 /srv/gpu-compute/config/active-hardware-profile.yaml

if [[ "$stack" == nvidia-cuda-modern ]]; then
  cat > /etc/modprobe.d/blacklist-nouveau.conf <<'EOF'
blacklist nouveau
options nouveau modeset=0
EOF
  update-initramfs -u
  if systemctl list-unit-files ollama.service >/dev/null 2>&1; then
    systemctl disable ollama.service >/dev/null 2>&1 || true
    systemctl stop ollama.service >/dev/null 2>&1 || true
  fi
fi

echo "active hardware profile installed: $profile_id"
echo "Ollama remains disabled until post-reboot GPU verification"
echo "reboot required before hardware acceptance"
