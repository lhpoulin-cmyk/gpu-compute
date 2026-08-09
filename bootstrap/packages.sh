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
cuda_pkg_version=$(yaml_value "$profile" cuda toolkit_package_version)
repo_distro=$(yaml_value "$profile" cuda repository_distro)
repo_arch=$(yaml_value "$profile" cuda repository_arch)
keyring_pkg=$(yaml_value "$profile" cuda repository_keyring_package)
keyring_sha=$(yaml_value "$profile" cuda repository_keyring_sha256)
ollama_version=$(yaml_value "$profile" ollama version)
ollama_asset=$(yaml_value "$profile" ollama asset)
ollama_url=$(yaml_value "$profile" ollama asset_url)
ollama_sha=$(yaml_value "$profile" ollama asset_sha256)
llama_repo=$(yaml_value "$profile" llama_cpp repository)
llama_ref=$(yaml_value "$profile" llama_cpp ref)
llama_commit=$(yaml_value "$profile" llama_cpp commit)
llama_arch=$(yaml_value "$profile" llama_cpp cuda_architectures)
llama_prefix=$(yaml_value "$profile" llama_cpp install_prefix)

for value in "$cuda_pkg" "$cuda_pkg_version" "$repo_distro" "$repo_arch" "$keyring_pkg" "$keyring_sha" \
             "$ollama_version" "$ollama_asset" "$ollama_url" "$ollama_sha" "$llama_repo" "$llama_ref" \
             "$llama_commit" "$llama_arch" "$llama_prefix"; do
  [[ -n "$value" && "$value" != "deployment-required" ]] || {
    echo "incomplete software contract in profile: $profile" >&2
    exit 65
  }
done

base_packages=(
  build-essential ca-certificates cmake curl git gnupg htop
  libcurl4-openssl-dev libvulkan1 ninja-build pciutils pkg-config
  python3-yaml vulkan-tools wget zstd
)

echo "# Ubuntu base packages: ${base_packages[*]}"
echo "# CUDA toolkit: ${cuda_pkg}=${cuda_pkg_version}"
echo "# NVIDIA repository: ${repo_distro}/${repo_arch}"
echo "# NVIDIA keyring sha256: ${keyring_sha}"
echo "# Ollama: ${ollama_version} (${ollama_asset})"
echo "# llama.cpp: ${llama_ref} @ ${llama_commit}, CUDA architecture ${llama_arch}"
$template_mode && echo "# template mode is retained for compatibility; normal VM 9320 construction no longer preinstalls the compute stack"

$apply || { echo "dry-run: no package or repository changes"; exit 0; }

[[ $(uname -m) == x86_64 ]] || { echo "this profile requires x86_64" >&2; exit 69; }
# shellcheck disable=SC1091
source /etc/os-release
[[ "${ID:-}" == ubuntu && "${VERSION_ID:-}" == 26.04 ]] || {
  echo "this profile requires Ubuntu 26.04; observed ${ID:-unknown} ${VERSION_ID:-unknown}" >&2
  exit 69
}

install -d -m 0755 /var/lib/cuda-compute
cp /etc/apt/sources.list /var/lib/cuda-compute/sources.list.before 2>/dev/null || true
if [[ -d /etc/apt/sources.list.d ]]; then
  tar -C /etc/apt -czf /var/lib/cuda-compute/sources.list.d.before.tar.gz sources.list.d 2>/dev/null || true
fi

apt-get update -q
apt-get -s install --no-install-recommends "${base_packages[@]}" | tee /var/lib/cuda-compute/base-apt-simulation.txt
apt-get install -y --no-install-recommends "${base_packages[@]}"

if [[ ! -f /usr/share/keyrings/cuda-archive-keyring.gpg || ! -f /etc/apt/sources.list.d/cuda-${repo_distro}-x86_64.list ]]; then
  tmpdir=$(mktemp -d)
  trap 'rm -rf "$tmpdir"' EXIT
  keyring_url="https://developer.download.nvidia.com/compute/cuda/repos/${repo_distro}/${repo_arch}/${keyring_pkg}"
  wget -q "$keyring_url" -O "$tmpdir/$keyring_pkg"
  printf '%s  %s\n' "$keyring_sha" "$tmpdir/$keyring_pkg" | sha256sum -c -
  dpkg -i "$tmpdir/$keyring_pkg"
fi

apt-get update -q
cuda_spec="${cuda_pkg}=${cuda_pkg_version}"
apt-get -s install --no-install-recommends "$cuda_spec" | tee /var/lib/cuda-compute/cuda-apt-simulation.txt
if grep -Eq '^Remv (ubuntu-minimal|ubuntu-standard|systemd|openssh-server)([ :]|$)' /var/lib/cuda-compute/cuda-apt-simulation.txt; then
  echo "CUDA transaction proposes removal of a protected guest package; refusing" >&2
  exit 69
fi
apt-get install -y --no-install-recommends "$cuda_spec"
apt-mark hold "$cuda_pkg" >/dev/null

# Install Ollama from the accepted immutable release asset, not mutable install.sh.
tmp_ollama=$(mktemp --suffix=.tar.zst)
trap 'rm -f "$tmp_ollama"' EXIT
curl -fL "$ollama_url" -o "$tmp_ollama"
printf '%s  %s\n' "$ollama_sha" "$tmp_ollama" | sha256sum -c -
tar --zstd -xf "$tmp_ollama" -C /usr
command -v ollama >/dev/null 2>&1 || { echo "Ollama binary missing after extraction" >&2; exit 69; }
ollama --version 2>&1 | grep -Fq "$ollama_version" || {
  echo "Ollama version mismatch; expected $ollama_version" >&2
  exit 69
}

# Build llama.cpp from the accepted immutable commit object.
llama_marker=/usr/local/share/cuda-compute/llama-cpp-commit
installed_llama_commit=""
[[ -r "$llama_marker" ]] && installed_llama_commit=$(<"$llama_marker")
if ! command -v llama-cli >/dev/null 2>&1 || [[ "$installed_llama_commit" != "$llama_commit" ]]; then
  build_root=/usr/local/src/llama.cpp-${llama_ref}
  rm -rf "$build_root"
  git clone --filter=blob:none --no-checkout "$llama_repo" "$build_root"
  git -C "$build_root" fetch --depth 1 origin "$llama_commit"
  git -C "$build_root" checkout --detach "$llama_commit"
  [[ "$(git -C "$build_root" rev-parse HEAD)" == "$llama_commit" ]] || { echo "llama.cpp commit verification failed" >&2; exit 69; }
  cmake -S "$build_root" -B "$build_root/build" -G Ninja \
    -DGGML_CUDA=ON \
    -DCMAKE_CUDA_ARCHITECTURES="$llama_arch" \
    -DCMAKE_BUILD_TYPE=Release \
    -DLLAMA_BUILD_TESTS=OFF
  cmake --build "$build_root/build" --parallel
  cmake --install "$build_root/build" --prefix "$llama_prefix"
  install -d -m 0755 "$(dirname "$llama_marker")"
  printf '%s\n' "$llama_commit" > "$llama_marker"
  printf '%s\n' "$llama_ref" > /usr/local/share/cuda-compute/llama-cpp-ref
fi

command -v llama-cli >/dev/null 2>&1 || { echo "llama-cli installation failed" >&2; exit 69; }
command -v llama-server >/dev/null 2>&1 || { echo "llama-server installation failed" >&2; exit 69; }
[[ "$(<"$llama_marker")" == "$llama_commit" ]] || { echo "llama.cpp commit marker mismatch" >&2; exit 69; }

dpkg-query -W > /var/lib/cuda-compute/package-versions.txt
apt-cache policy "$cuda_pkg" > /var/lib/cuda-compute/cuda-package-policy.txt
sha256sum "$profile" > /var/lib/cuda-compute/profile.sha256

if $template_mode && systemctl list-unit-files ollama.service >/dev/null 2>&1; then
  systemctl disable --now ollama.service >/dev/null 2>&1 || true
fi

echo "software install complete; exact installed package state recorded under /var/lib/cuda-compute"
