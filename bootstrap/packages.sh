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

common_packages=(ca-certificates curl git htop pciutils python3-yaml wget zstd)
build_packages=(build-essential cmake libcurl4-openssl-dev ninja-build pkg-config)

echo "# profile stack: $stack"
echo "# required Ubuntu: $os_version"
echo "# common packages: ${common_packages[*]}"

$apply || {
  if $template_mode; then
    echo "dry-run: generic template installs only common guest/build prerequisites"
  else
    echo "dry-run: instance install dispatches the selected GPU stack"
  fi
  exit 0
}

# shellcheck disable=SC1091
source /etc/os-release
[[ "${ID:-}" == ubuntu && "${VERSION_ID:-}" == "$os_version" ]] || {
  echo "profile requires Ubuntu $os_version; observed ${ID:-unknown} ${VERSION_ID:-unknown}" >&2
  exit 69
}

install -d -m 0755 /var/lib/cuda-compute
apt-get update -q
apt-get -s install --no-install-recommends "${common_packages[@]}" "${build_packages[@]}" \
  | tee /var/lib/cuda-compute/base-apt-simulation.txt
apt-get install -y --no-install-recommends "${common_packages[@]}" "${build_packages[@]}"

if $template_mode; then
  dpkg-query -W > /var/lib/cuda-compute/template-package-versions.txt
  echo "generic template prerequisites installed; no NVIDIA/AMD driver, CUDA, ROCm, Ollama, or llama.cpp installed"
  exit 0
fi

case "$stack" in
  nvidia-cuda-modern)
    exec "$script_dir/stack-nvidia-modern.sh" --profile "$profile" --apply
    ;;
  nvidia-cuda-pascal)
    exec "$script_dir/stack-nvidia-pascal.sh" --profile "$profile" --apply
    ;;
  amd-rocm)
    exec "$script_dir/stack-amd-rocm.sh" --profile "$profile" --apply
    ;;
  *)
    echo "unsupported stack.kind: $stack" >&2
    exit 69
    ;;
esac
