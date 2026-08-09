#!/usr/bin/env bash
set -Eeuo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
profile="$root/proxmox/hv-katra-rtx5070ti.yaml"
deploy="$root/proxmox/deploy-instance.sh"
example="$root/proxmox/example-profile.yaml"

[[ -r "$profile" && -r "$deploy" && -r "$example" ]] || {
  echo "required Phase 4 deployment files are missing" >&2
  exit 1
}

python3 - "$profile" <<'PY'
import sys, yaml
p=sys.argv[1]
with open(p) as f:
    d=yaml.safe_load(f)
assert d['appliance']['template_vmid'] == 9320
assert d['instance']['vmid'] == 320
assert d['instance']['name'] == 'cuda-compute-katra'
assert d['instance']['node'] == 'hv-katra'
assert d['instance']['cores'] == 8
assert d['instance']['memory_mb'] == 16384
assert d['storage']['pve_storage_id'] == 'cuda-katra'
assert d['storage']['root_disk_size_gib'] == 32
assert d['storage']['models_disk_size_gib'] == 160
assert d['storage']['models_label'] == 'cuda-models'
assert d['storage']['models_mount'] == '/mnt/models'
assert d['virtualization']['primary_bridge'] == 'vmbr0'
assert d['virtualization']['secondary_bridge'] == 'vmbr1'
assert d['virtualization']['secondary_mtu'] == 9000
assert d['network']['primary_ipv4'] == '192.168.10.92/24'
assert d['network']['primary_gateway'] == '192.168.10.1'
assert d['network']['secondary_ipv4'] == '192.168.100.92/24'
assert d['network']['dns_servers'] == '192.168.10.250 192.168.10.251'
assert d['network']['search_domain'] == 'home.arpa'
assert d['gpu']['resource_mapping'] == 'gpu-compute-rtx5070ti'
assert d['gpu']['profile'] == 'nvidia-rtx5070ti'
assert d['gpu']['host_compute_function'] == '0000:01:00.0'
assert d['gpu']['host_audio_function'] == '0000:01:00.1'
PY

! grep -Eq 'PLACEHOLDER|ubuntu_iso|media=cdrom|cicustom|snippets_directory|vendor_data|network_config' "$profile" "$deploy" \
  || { echo "stale placeholder/ISO/custom-snippet deployment logic found" >&2; exit 1; }
! grep -Eq 'PRIVATE KEY|BEGIN OPENSSH' "$profile" \
  || { echo "private credential material found in deployment profile" >&2; exit 1; }
grep -Fq -- '--ssh-public-key-file' "$deploy" || { echo "runtime SSH public-key input missing" >&2; exit 1; }
grep -Fq -- '--ipconfig0' "$deploy" || { echo "standard Proxmox ipconfig0 missing" >&2; exit 1; }
grep -Fq -- '--ipconfig1' "$deploy" || { echo "standard Proxmox ipconfig1 missing" >&2; exit 1; }
grep -Fq 'attach-resource-mapping.sh' "$deploy" || { echo "logical GPU mapping attachment path missing" >&2; exit 1; }
grep -Fq 'status: retired-example' "$example" || { echo "old example profile not retired" >&2; exit 1; }

bash -n "$deploy"
bash -n "$root/proxmox/attach-resource-mapping.sh"

echo "deployment-contract: PASS"
