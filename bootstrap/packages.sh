#!/usr/bin/env bash
set -Eeuo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$script_dir/profile-lib.sh"

profile= apply=false template_mode=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile) profile=${2:?}; shift 2 ;;
    --dry-run) apply=false; shift ;;
    --apply) apply=true; shift ;;
    --template-mode) template_mode=true; shift ;;
    *) echo "usage: packages.sh --profile FILE [--dry-run|--apply] [--template-mode]" >&2; exit 64 ;;
  esac
done
[[ -r "$profile" ]] || { echo "profile required" >&2; exit 66; }

stack=$(yaml_value "$profile" stack kind)
os_version=$(yaml_value "$profile" os version)
[[ -n "$stack" && -n "$os_version" ]] || { echo "profile must declare stack.kind and os.version" >&2; exit 65; }

common_packages=(ca-certificates curl git htop libvulkan1 pciutils python3-yaml vulkan-tools wget zstd)
build_packages=(build-essential cmake libcurl4-openssl-dev ninja-build pkg-config)

echo "# profile stack: $stack"
echo "# required Ubuntu: $os_version"
echo "# common packages: ${common_packages[*]}"
echo "# build packages: ${build_packages[*]}"

if ! $apply; then
  echo "dry-run: would apt-simulate/install common guest/build prerequisites"
  if ! $template_mode; then
    case "$stack" in
      nvidia-cuda-modern) "$script_dir/stack-nvidia-modern.sh" --profile "$profile" --dry-run ;;
      nvidia-cuda-pascal) echo "dry-run: legacy Pascal stack is design-stage and not executable" ;;
      amd-rocm) echo "dry-run: AMD ROCm stack is design-stage and not executable" ;;
      none) echo "dry-run: no vendor GPU stack selected" ;;
      *) echo "unsupported stack.kind: $stack" >&2; exit 69 ;;
    esac
  fi
  exit 0
fi

[[ $EUID -eq 0 ]] || { echo "apply requires root" >&2; exit 77; }
[[ $(uname -m) == x86_64 ]] || { echo "this appliance requires x86_64" >&2; exit 69; }
# shellcheck disable=SC1091
source /etc/os-release
[[ "${ID:-}" == ubuntu && "${VERSION_ID:-}" == "$os_version" ]] || {
  echo "profile requires Ubuntu $os_version; observed ${ID:-unknown} ${VERSION_ID:-unknown}" >&2
  exit 69
}

install -d -m 0755 /var/lib/cuda-compute
apt-get update -q
base_sim=/var/lib/cuda-compute/base-apt-simulation.txt
apt-get -s install --no-install-recommends "${common_packages[@]}" "${build_packages[@]}" | tee "$base_sim"
if grep -Eq '^Remv ' "$base_sim"; then
  echo "base package simulation proposes removals; refusing" >&2
  grep '^Remv ' "$base_sim" >&2
  exit 69
fi
apt-get install -y --no-install-recommends "${common_packages[@]}" "${build_packages[@]}"

if $template_mode; then
  dpkg-query -W > /var/lib/cuda-compute/template-package-versions.txt
  echo "template prerequisites installed; no vendor GPU stack installed"
  exit 0
fi

case "$stack" in
  nvidia-cuda-modern)
    exec "$script_dir/stack-nvidia-modern.sh" --profile "$profile" --apply
    ;;
  nvidia-cuda-pascal)
    echo "legacy Pascal stack is not executable on the modern Ubuntu 26.04 instance" >&2
    exit 69
    ;;
  amd-rocm)
    echo "AMD ROCm stack remains design-stage until local RX 9070 XT testing" >&2
    exit 69
    ;;
  none)
    echo "no vendor GPU stack selected"
    ;;
  *)
    echo "unsupported stack.kind: $stack" >&2
    exit 69
    ;;
esac
