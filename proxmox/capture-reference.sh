#!/usr/bin/env bash
set -Eeuo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$script_dir/profile-lib.sh"

vmid=320 apply=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --vmid)    vmid=${2:?}; shift 2 ;;
    --dry-run) apply=false; shift ;;
    --apply)   apply=true; shift ;;
    *) echo "usage: capture-reference.sh [--vmid 320] [--dry-run|--apply]" >&2; exit 64 ;;
  esac
done

snap="post-acceptance-$(date -u +%Y%m%d)"
echo "# qm snapshot $vmid $snap --description 'cuda-compute post-acceptance reference snapshot'"
$apply || exit 0

require_proxmox_host
qm status "$vmid" >/dev/null 2>&1 || { echo "VMID $vmid not found" >&2; exit 69; }
qm snapshot "$vmid" "$snap" --description "cuda-compute post-acceptance reference snapshot"
echo "snapshot created: $snap on VMID $vmid"
