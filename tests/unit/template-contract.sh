#!/usr/bin/env bash
set -Eeuo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
profile="$root/proxmox/hv-katra-template.yaml"
generic="$root/config/profiles/generic/profile.yaml"
rtx="$root/config/profiles/nvidia-rtx5070ti/profile.yaml"
rx="$root/config/profiles/amd-rx9070xt/profile.yaml"
p6000="$root/config/profiles/nvidia-p6000/profile.yaml"
builder="$root/proxmox/create-template.sh"
doc="$root/docs/template-build.md"

failures=0
pass() { printf '[PASS] %s\n' "$1"; }
fail() { printf '[FAIL] %s\n' "$1" >&2; failures=$((failures + 1)); }
check_grep() {
  local label=$1 pattern=$2 file=$3
  grep -Eq "$pattern" "$file" && pass "$label" || fail "$label"
}
check_absent() {
  local label=$1 pattern=$2 file=$3
  if grep -Eq "$pattern" "$file"; then fail "$label"; else pass "$label"; fi
}

check_grep 'template is Ubuntu 26.04' 'release:[[:space:]]*"26\.04"' "$profile"
check_grep 'template name is ubuntu2604' 'template_name:[[:space:]]*tpl-compute-ubuntu2604-20260808' "$profile"
check_grep 'template storage is cuda-katra' 'pve_storage_id:[[:space:]]*cuda-katra' "$profile"
check_grep 'template root is 32 GiB' 'os_disk_size_gib:[[:space:]]*32' "$profile"
check_grep 'accepted image hash is present' '0c9fb915bab0b36b361d3bf8aeae2115dda19d81a306656964de048033481670' "$profile"
check_grep 'generic profile is Ubuntu 26.04' 'version:[[:space:]]*"26\.04"' "$generic"
check_grep 'RTX profile is Ubuntu 26.04' 'version:[[:space:]]*"26\.04"' "$rtx"
check_grep 'RTX repository is ubuntu2604' 'repository_distro:[[:space:]]*ubuntu2604' "$rtx"
check_grep 'RX profile is Ubuntu 26.04' 'version:[[:space:]]*"26\.04"' "$rx"
check_grep 'RX profile names ROCm 7.14' 'version:[[:space:]]*"7\.14\.0"' "$rx"
check_grep 'P6000 remains Ubuntu 24.04' 'version:[[:space:]]*"24\.04"' "$p6000"
check_grep 'builder imports a cloud image' 'qm disk import' "$builder"
check_grep 'builder converts directly to template' 'qm template' "$builder"
check_absent 'builder has no ISO/manual installer path' 'ubuntu_iso|media=cdrom|live-server-amd64\.iso' "$builder"
check_absent 'template docs require no bootstrap' 'bootstrap/install\.sh.*template-mode' "$doc"
check_absent 'template docs require no sanitation' 'sanitize-template\.sh' "$doc"

[[ "$failures" -eq 0 ]] || { echo "template-contract: $failures failure(s)" >&2; exit 1; }
echo 'template-contract: PASS'
