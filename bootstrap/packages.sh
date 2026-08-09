#!/usr/bin/env bash
set -Eeuo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$script_dir/profile-lib.sh"

profile= apply=false template_mode=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile)       profile=${2:?}; shift 2 ;;
    --dry-run)       apply=false; shift ;;
    --apply)         apply=true; shift ;;
    --template-mode) template_mode=true; shift ;;
    *) echo "usage: packages.sh --profile FILE [--dry-run|--apply] [--template-mode]" >&2; exit 64 ;;
  esac
done

[[ -r "$profile" ]] || { echo "profile required" >&2; exit 66; }

cuda_pkg=$(yaml_value "$profile" cuda toolkit_package)
cuda_version=$(yaml_value "$profile" cuda pinned_version)
repo_distro=$(yaml_value "$profile" cuda repository_distro)
repo_arch=$(yaml_value "$profile" cuda repository_arch)
keyring_pkg=$(yaml_value "$profile" cuda repository_keyring_package)
ollama_version=$(yaml_value "$profile" ollama version)
llama_repo=$(yaml_value "$profile" llama_cpp repository)
llama_ref=$(yaml_value "$profile" llama_cpp ref)
llama_arch=$(yaml_value "$profile" llama_cpp cuda_architectures)
llama_prefix=$(yaml_value "$profile" llama_cpp install_prefix)

for value in "$cuda_pkg" "$cuda_version" "$repo_distro" "$repo_arch" "$keyring_pkg" \
             "$ollama_version" "$llama_repo" "$llama_ref" "$llama_arch" "$llama_prefix"; do
  [[ -n "$value" && "$value" != "deployment-required" ]] || {
    echo "incomplete software pinning in profile: $profile" >&2
    exit 65
  }
done

packages=(
  build-essential
  ca-certificates
  cmake
  curl
  git
  gnupg
  htop
  libcurl4-openssl-dev
  libvulkan1
  ninja-build
  pciutils
  pkg-config
  python3-yaml
  vulkan-tools
  wget
  zstd
)

echo "# base packages: ${packages[*]}"
echo "# CUDA toolkit: $cuda_pkg (pinned branch $cuda_version)"
echo "# NVIDIA repository: $repo_distro/$repo_arch"
echo "# Ollama: $ollama_version"
echo "# llama.cpp: $llama_ref, CUDA architecture $llama_arch"
$template_mode && echo "# template mode: software installed, GPU driver activation/service start deferred"

$apply || { echo "dry-run: no package or repository changes"; exit 0; }

[[ $(uname -m) == x86_64 ]] || { echo "this profile requires x86_64" >&2; exit 69; }
# shellcheck disable=SC1091
source /etc/os-release
[[ "${ID:-}" == ubuntu && "${VERSION_ID:-}" == 26.04 ]] || {
  echo "this profile is pinned to Ubuntu 26.04; observed ${ID:-unknown} ${VERSION_ID:-unknown}" >&2
  exit 69
}

apt-get update -q
apt-get install -y --no-install-recommends "${packages[@]}"

if [[ ! -f /usr/share/keyrings/cuda-archive-keyring.gpg || ! -f /etc/apt/sources.list.d/cuda-${repo_distro}-x86_64.list ]]; then
  tmpdir=$(mktemp -d)
  trap 'rm -rf "$tmpdir"' EXIT
  keyring_url="https://developer.download.nvidia.com/compute/cuda/repos/${repo_distro}/x86_64/${keyring_pkg}"
  wget -q "$keyring_url" -O "$tmpdir/$keyring_pkg"
  dpkg -i "$tmpdir/$keyring_pkg"
fi
apt-get update -q
apt-get install -y --no-install-recommends "$cuda_pkg"
# Hold the toolkit meta-package on the selected 13.3 branch. Component updates inside
# that branch remain controlled by the package's exact dependencies.
apt-mark hold "$cuda_pkg" >/dev/null

# Install a specific Ollama release. The upstream installer supports OLLAMA_VERSION.
if ! command -v ollama >/dev/null 2>&1 || ! ollama --version 2>&1 | grep -Fq "$ollama_version"; then
  tmp_ollama=$(mktemp)
  curl -fsSL https://ollama.com/install.sh -o "$tmp_ollama"
  OLLAMA_VERSION="$ollama_version" sh "$tmp_ollama"
  rm -f "$tmp_ollama"
fi
ollama --version 2>&1 | grep -Fq "$ollama_version" || {
  echo "Ollama version mismatch; expected $ollama_version" >&2
  exit 69
}

# Build llama.cpp at the pinned release tag with an explicit Blackwell sm_120 CUDA backend.
# Do not infer the source ref from llama-cli --version: upstream version output is not
# guaranteed to contain the tag. Persist the exact installed ref as appliance evidence.
llama_marker=/usr/local/share/cuda-compute/llama-cpp-ref
installed_llama_ref=""
[[ -r "$llama_marker" ]] && installed_llama_ref=$(<"$llama_marker")
if ! command -v llama-cli >/dev/null 2>&1 || [[ "$installed_llama_ref" != "$llama_ref" ]]; then
  build_root=/usr/local/src/llama.cpp-${llama_ref}
  rm -rf "$build_root"
  git clone --depth 1 --branch "$llama_ref" "$llama_repo" "$build_root"
  cmake -S "$build_root" -B "$build_root/build" -G Ninja \
    -DGGML_CUDA=ON \
    -DCMAKE_CUDA_ARCHITECTURES="$llama_arch" \
    -DCMAKE_BUILD_TYPE=Release \
    -DLLAMA_BUILD_TESTS=OFF
  cmake --build "$build_root/build" --parallel
  cmake --install "$build_root/build" --prefix "$llama_prefix"
  install -d -m 0755 "$(dirname "$llama_marker")"
  printf '%s\n' "$llama_ref" > "$llama_marker"
  chmod 0644 "$llama_marker"
fi
command -v llama-cli >/dev/null 2>&1 || { echo "llama-cli installation failed" >&2; exit 69; }
command -v llama-server >/dev/null 2>&1 || { echo "llama-server installation failed" >&2; exit 69; }
[[ -r "$llama_marker" ]] && [[ "$(<"$llama_marker")" == "$llama_ref" ]] || { echo "llama.cpp ref marker mismatch" >&2; exit 69; }

if $template_mode && systemctl list-unit-files ollama.service >/dev/null 2>&1; then
  systemctl disable --now ollama.service >/dev/null 2>&1 || true
fi

echo "software packages installed at pinned appliance versions"
