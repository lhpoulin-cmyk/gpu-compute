#!/usr/bin/env bash
set -Eeuo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$script_dir/profile-lib.sh"

profile=
apply=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile) profile=${2:?}; shift 2 ;;
    --dry-run) apply=false; shift ;;
    --apply) apply=true; shift ;;
    *) echo "usage: stack-nvidia-modern.sh --profile FILE [--dry-run|--apply]" >&2; exit 64 ;;
  esac
done

[[ -r "$profile" ]] || { echo "profile required" >&2; exit 66; }

os_version=$(yaml_value "$profile" os version)
expected_pci=$(yaml_value "$profile" device expected_pci_id)
cuda_version=$(yaml_value "$profile" cuda pinned_version)
cuda_pkg=$(yaml_value "$profile" cuda toolkit_package)
cuda_pkg_version=$(yaml_value "$profile" cuda toolkit_package_version)
driver_pkg=$(yaml_value "$profile" cuda driver_package)
driver_branch=$(yaml_value "$profile" cuda driver_branch)
driver_policy=$(yaml_value "$profile" cuda driver_policy)
min_driver=$(yaml_value "$profile" cuda minimum_driver)
repo_distro=$(yaml_value "$profile" cuda repository_distro)
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

required=(
  "$os_version" "$expected_pci" "$cuda_version" "$cuda_pkg" "$cuda_pkg_version"
  "$driver_pkg" "$driver_branch" "$driver_policy" "$min_driver" "$repo_distro" "$keyring_pkg"
  "$keyring_sha" "$ollama_version" "$ollama_asset" "$ollama_url" "$ollama_sha"
  "$llama_repo" "$llama_ref" "$llama_commit" "$llama_arch" "$llama_prefix"
)
for value in "${required[@]}"; do
  [[ -n "$value" && "$value" != deployment-required ]] || {
    echo "incomplete NVIDIA modern-stack profile: $profile" >&2
    exit 65
  }
done
[[ "$driver_policy" == latest-in-branch ]] || { echo "unsupported driver policy: $driver_policy" >&2; exit 65; }

keyring_url="https://developer.download.nvidia.com/compute/cuda/repos/${repo_distro}/x86_64/${keyring_pkg}"
headers_pkg="linux-headers-$(uname -r)"
pinning_pkg="nvidia-driver-pinning-${driver_branch}"

echo "# NVIDIA modern stack"
echo "# Ubuntu: $os_version"
echo "# GPU PCI ID: $expected_pci"
echo "# driver: newest authenticated $driver_pkg in branch $driver_branch (minimum $min_driver)"
echo "# CUDA: $cuda_pkg=$cuda_pkg_version"
echo "# Ollama: $ollama_version"
echo "# llama.cpp: $llama_ref @ $llama_commit, CUDA arch $llama_arch"

if ! $apply; then
  cat <<EOF
would:
  verify Ubuntu $os_version / x86_64 and GPU PCI ID $expected_pci
  verify/install NVIDIA cuda-keyring from $keyring_url
  select the newest authenticated $driver_pkg version in branch $driver_branch, >= $min_driver
  apt-simulate $headers_pkg $pinning_pkg selected-driver $cuda_pkg=$cuda_pkg_version
  refuse any simulated package removals
  install that selected branch-$driver_branch driver and exact CUDA toolkit version
  hold the selected driver and CUDA toolkit after installation
  install verified Ollama $ollama_version asset
  build llama.cpp $llama_ref at exact commit $llama_commit for sm_$llama_arch
  install Ollama service but leave it disabled/stopped until post-reboot GPU verification
  record exact installed package versions
EOF
  exit 0
fi

[[ $EUID -eq 0 ]] || { echo "apply requires root" >&2; exit 77; }
[[ $(uname -m) == x86_64 ]] || { echo "profile requires x86_64" >&2; exit 69; }
# shellcheck disable=SC1091
source /etc/os-release
[[ "${ID:-}" == ubuntu && "${VERSION_ID:-}" == "$os_version" ]] || {
  echo "profile requires Ubuntu $os_version; observed ${ID:-unknown} ${VERSION_ID:-unknown}" >&2
  exit 69
}
lspci -nn | grep -Fqi "[$expected_pci]" || {
  echo "expected GPU PCI ID $expected_pci is not visible in the guest" >&2
  exit 69
}
findmnt -M /mnt/models -n >/dev/null 2>&1 || {
  echo "/mnt/models must be mounted before GPU-stack installation" >&2
  exit 69
}

install -d -m 0755 /var/lib/cuda-compute /var/cache/cuda-compute

keyring_path="/var/cache/cuda-compute/$keyring_pkg"
if [[ ! -f "$keyring_path" ]] || [[ "$(sha256sum "$keyring_path" | awk '{print $1}')" != "$keyring_sha" ]]; then
  rm -f "$keyring_path.part"
  curl -fL --retry 3 -o "$keyring_path.part" "$keyring_url"
  observed=$(sha256sum "$keyring_path.part" | awk '{print $1}')
  [[ "$observed" == "$keyring_sha" ]] || {
    echo "NVIDIA keyring hash mismatch: expected $keyring_sha observed $observed" >&2
    rm -f "$keyring_path.part"
    exit 69
  }
  mv "$keyring_path.part" "$keyring_path"
fi

dpkg -i "$keyring_path"
apt-get update -q

candidate_driver=$(apt-cache madison "$driver_pkg" | awk -v branch="${driver_branch}." '
  $3 ~ "^" branch && !selected { print $3; selected = 1 }
')
candidate_cuda=$(apt-cache policy "$cuda_pkg" | awk '/Candidate:/ {print $2}')
[[ -n "$candidate_driver" ]] || {
  echo "no authenticated $driver_pkg candidate found in branch $driver_branch" >&2
  exit 69
}
dpkg --compare-versions "$candidate_driver" ge "$min_driver" || {
  echo "newest branch-$driver_branch candidate $candidate_driver is below minimum $min_driver" >&2
  exit 69
}
[[ "$candidate_cuda" == "$cuda_pkg_version" ]] || {
  echo "unexpected $cuda_pkg candidate: expected $cuda_pkg_version observed $candidate_cuda" >&2
  exit 69
}

echo "selected NVIDIA driver: $driver_pkg=$candidate_driver"
printf '%s\n' "$candidate_driver" > /var/lib/cuda-compute/selected-nvidia-driver-version.txt

simulation=/var/lib/cuda-compute/nvidia-apt-simulation.txt
apt-get -s install --no-install-recommends \
  "$headers_pkg" "$pinning_pkg" "$driver_pkg=$candidate_driver" "$cuda_pkg=$cuda_pkg_version" \
  | tee "$simulation"
if grep -Eq '^Remv ' "$simulation"; then
  echo "package simulation proposes removals; refusing installation" >&2
  grep '^Remv ' "$simulation" >&2
  exit 69
fi

apt-get install -y --no-install-recommends \
  "$headers_pkg" "$pinning_pkg" "$driver_pkg=$candidate_driver" "$cuda_pkg=$cuda_pkg_version"
apt-mark hold "$driver_pkg" "$cuda_pkg" >/dev/null

cuda_root="/usr/local/cuda-${cuda_version}"
[[ -x "$cuda_root/bin/nvcc" ]] || { echo "nvcc missing at $cuda_root/bin/nvcc" >&2; exit 69; }
[[ -d "$cuda_root/nvvm/libdevice" ]] || { echo "CUDA libdevice directory missing at $cuda_root/nvvm/libdevice" >&2; exit 69; }
ln -sfn "$cuda_root/bin/nvcc" /usr/local/bin/nvcc
cat > /etc/profile.d/cuda-compute.sh <<EOF
export PATH="$cuda_root/bin:\$PATH"
EOF
chmod 0644 /etc/profile.d/cuda-compute.sh

ollama_path="/var/cache/cuda-compute/$ollama_asset"
if [[ ! -f "$ollama_path" ]] || [[ "$(sha256sum "$ollama_path" | awk '{print $1}')" != "$ollama_sha" ]]; then
  rm -f "$ollama_path.part"
  curl -fL --retry 3 -o "$ollama_path.part" "$ollama_url"
  observed=$(sha256sum "$ollama_path.part" | awk '{print $1}')
  [[ "$observed" == "$ollama_sha" ]] || {
    echo "Ollama asset hash mismatch: expected $ollama_sha observed $observed" >&2
    rm -f "$ollama_path.part"
    exit 69
  }
  mv "$ollama_path.part" "$ollama_path"
fi

tar --zstd -xf "$ollama_path" -C /usr
command -v ollama >/dev/null 2>&1 || { echo "Ollama binary missing after extraction" >&2; exit 69; }
ollama --version 2>&1 | grep -Fq "$ollama_version" || {
  echo "Ollama version mismatch; expected $ollama_version" >&2
  exit 69
}

if ! getent group ollama >/dev/null; then groupadd --system ollama; fi
if ! id ollama >/dev/null 2>&1; then
  useradd --system --gid ollama --home-dir /usr/share/ollama --create-home --shell /usr/sbin/nologin ollama
fi
install -d -o ollama -g ollama -m 0755 /mnt/models/library
chown -R ollama:ollama /mnt/models/library
cat > /etc/systemd/system/ollama.service <<'EOF'
[Unit]
Description=Ollama Service
After=network-online.target
Wants=network-online.target

[Service]
ExecStart=/usr/bin/ollama serve
User=ollama
Group=ollama
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl disable ollama.service >/dev/null 2>&1 || true
systemctl stop ollama.service >/dev/null 2>&1 || true

build_root="/usr/local/src/llama.cpp-${llama_ref}"
rm -rf "$build_root"
git clone --depth 1 --branch "$llama_ref" "$llama_repo" "$build_root"
observed_commit=$(git -C "$build_root" rev-parse HEAD)
[[ "$observed_commit" == "$llama_commit" ]] || {
  echo "llama.cpp commit mismatch: expected $llama_commit observed $observed_commit" >&2
  exit 69
}

cmake -S "$build_root" -B "$build_root/build" -G Ninja \
  -DGGML_CUDA=ON \
  -DCMAKE_CUDA_COMPILER="$cuda_root/bin/nvcc" \
  -DCMAKE_CUDA_ARCHITECTURES="$llama_arch" \
  -DCUDAToolkit_ROOT="$cuda_root" \
  -DCMAKE_BUILD_TYPE=Release \
  -DLLAMA_BUILD_TESTS=OFF
cmake --build "$build_root/build" --parallel
cmake --install "$build_root/build" --prefix "$llama_prefix"
ldconfig

command -v llama-cli >/dev/null 2>&1 || { echo "llama-cli installation failed" >&2; exit 69; }
command -v llama-server >/dev/null 2>&1 || { echo "llama-server installation failed" >&2; exit 69; }
install -d -m 0755 /usr/local/share/cuda-compute
printf '%s\n' "$llama_ref" > /usr/local/share/cuda-compute/llama-cpp-ref
printf '%s\n' "$llama_commit" > /usr/local/share/cuda-compute/llama-cpp-commit

dpkg-query -W > /var/lib/cuda-compute/installed-package-versions.txt
apt-mark showhold > /var/lib/cuda-compute/apt-holds.txt

echo "NVIDIA/CUDA userspace and applications installed"
echo "selected NVIDIA driver package: $candidate_driver"
echo "Ollama is intentionally disabled/stopped until post-reboot NVIDIA verification"
echo "reboot required before GPU smoke/acceptance"
