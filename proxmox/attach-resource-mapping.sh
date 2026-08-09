#!/usr/bin/env bash
set -Eeuo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$script_dir/profile-lib.sh"

vmid= mapping= apply=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --vmid)    vmid=${2:?}; shift 2 ;;
    --mapping) mapping=${2:?}; shift 2 ;;
    --dry-run) apply=false; shift ;;
    --apply)   apply=true; shift ;;
    *) echo "usage: attach-resource-mapping.sh --vmid ID --mapping NAME [--dry-run|--apply]" >&2; exit 64 ;;
  esac
done

[[ -n "$vmid" && -n "$mapping" ]] || { echo "vmid and mapping are required" >&2; exit 64; }

echo "# qm set $vmid --hostpci0 mapping=$mapping,pcie=1,rombar=1"
$apply || exit 0

require_proxmox_host
qm set "$vmid" --hostpci0 "mapping=$mapping,pcie=1,rombar=1"
echo "GPU mapping attached: vmid=$vmid mapping=$mapping"
