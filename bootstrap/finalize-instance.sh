#!/usr/bin/env bash
set -Eeuo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
root=$(cd -- "$script_dir/.." && pwd)

apply=false vmid= hostname= node= acceptance_sha=

while [[ $# -gt 0 ]]; do
  case "$1" in
    --vmid)              vmid=${2:?}; shift 2 ;;
    --hostname)          hostname=${2:?}; shift 2 ;;
    --node)              node=${2:?}; shift 2 ;;
    --acceptance-sha256) acceptance_sha=${2:?}; shift 2 ;;
    --dry-run)           apply=false; shift ;;
    --apply)             apply=true; shift ;;
    *) echo "usage: finalize-instance.sh --vmid ID --hostname NAME --node NODE --acceptance-sha256 SHA256 [--dry-run|--apply]" >&2; exit 64 ;;
  esac
done

[[ -n "$vmid" && -n "$hostname" && -n "$node" ]] || { echo "vmid, hostname, and node are required" >&2; exit 64; }
[[ "$acceptance_sha" =~ ^[0-9a-fA-F]{64}$ ]] || { echo "a 64-hex acceptance SHA-256 is required" >&2; exit 64; }

profile="$root/config/active-hardware-profile.yaml"
[[ -r "$profile" ]] || { echo "active hardware profile not found" >&2; exit 66; }
[[ -r "$root/BUILD" ]] || { echo "BUILD not found" >&2; exit 66; }

release=$(awk -F= '$1=="release" {print $2}' "$root/BUILD")
profile_id=$(python3 -c "import yaml; d=yaml.safe_load(open('$profile')); print(d['profile']['id'])")
commit=$(git -C "$root" rev-parse --short HEAD 2>/dev/null || awk -F= '$1=="commit" {print $2}' "$root/BUILD")
created=$(date -u +%Y-%m-%dT%H:%M:%SZ)
state_file="$root/config/instance-state.yaml"

tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT
cat > "$tmp" <<YAML
appliance: gpu-compute
release: $release
commit: $commit
vmid: $vmid
hostname: $hostname
node: $node
profile: $profile_id
created: "$created"
accepted: "$created"
acceptance_output_sha256: "$acceptance_sha"
YAML

echo "# instance state"
cat "$tmp"

$apply || { echo "dry-run: instance state not written"; exit 0; }

install -m 0644 "$tmp" "$state_file"

if [[ -n "$commit" && "$commit" != unset ]]; then
  sed -i "s/^commit=.*/commit=$commit/" "$root/BUILD"
fi

python3 - <<PY
import yaml
p = '$profile'
with open(p) as f:
    d = yaml.safe_load(f)
d['profile']['status'] = 'finalized'
with open(p, 'w') as f:
    yaml.safe_dump(d, f, sort_keys=False)
PY

echo "instance state written: $state_file"
echo "profile status: finalized"
