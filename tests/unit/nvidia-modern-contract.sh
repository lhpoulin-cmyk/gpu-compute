#!/usr/bin/env bash
set -Eeuo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
profile="$root/profiles/nvidia-rtx5070ti/profile.yaml"
stack="$root/bootstrap/stack-nvidia-modern.sh"
packages="$root/bootstrap/packages.sh"
install="$root/bootstrap/install.sh"
model_disk="$root/bootstrap/prepare-model-disk.sh"

for f in "$profile" "$stack" "$packages" "$install" "$model_disk"; do
  [[ -r "$f" ]] || { echo "missing required file: $f" >&2; exit 1; }
done

python3 - "$profile" <<'PY'
import sys, yaml
with open(sys.argv[1]) as f: d=yaml.safe_load(f)
assert d['os']['version'] == '26.04'
assert d['stack']['kind'] == 'nvidia-cuda-modern'
assert d['device']['expected_pci_id'] == '10de:2c05'
assert d['device']['compute_capability'] == '12.0'
assert d['cuda']['repository_distro'] == 'ubuntu2604'
assert d['cuda']['pinned_version'] == '13.3'
assert d['cuda']['toolkit_package'] == 'cuda-toolkit-13-3'
assert d['cuda']['toolkit_package_version'] == '13.3.1-1'
assert d['cuda']['driver_package'] == 'nvidia-open'
assert d['cuda']['driver_branch'] == '610'
assert d['cuda']['driver_policy'] == 'latest-in-branch'
assert d['cuda']['minimum_driver'] == '610.43.02'
assert 'driver_package_version' not in d['cuda']
assert d['ollama']['version'] == '0.32.0'
assert len(d['ollama']['asset_sha256']) == 64
assert d['llama_cpp']['ref'] == 'b10173'
assert d['llama_cpp']['commit'] == 'e9fa0781f1c25fc4fe8c86be1edc6970661ad6f0'
assert d['llama_cpp']['cuda_architectures'] == '120'
PY

grep -Fq 'cuda-keyring' "$stack"
grep -Fq 'apt-cache madison' "$stack"
grep -Fq 'latest-in-branch' "$stack"
grep -Fq 'apt-get -s install' "$stack"
grep -Fq "grep -Eq '^Remv '" "$stack"
grep -Fq 'nvidia-driver-pinning-' "$stack"
grep -Fq 'selected-nvidia-driver-version.txt' "$stack"
grep -Fq 'package-candidate-origin.txt' "$stack"
grep -Fq 'installed-driver-cuda-versions.txt' "$stack"
grep -Fq 'tar --zstd' "$stack"
grep -Fq 'CMAKE_CUDA_ARCHITECTURES' "$stack"
grep -Fq 'systemctl disable ollama.service' "$stack"
grep -Fq 'DO NOT run GPU acceptance before reboot' "$install"
grep -Fq 'expected exactly one unambiguous ~160 GiB non-root disk' "$model_disk"

! grep -Eq 'curl[^|]*\|[[:space:]]*(sh|bash)' "$stack" "$packages" || {
  echo "unverified pipe-to-shell installer found" >&2
  exit 1
}

bash -n "$stack"
bash -n "$packages"
bash -n "$install"
bash -n "$model_disk"

echo "nvidia-modern-contract: PASS"
