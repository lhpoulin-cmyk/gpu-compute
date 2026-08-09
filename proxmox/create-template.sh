#!/usr/bin/env bash
set -Eeuo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
root=$(cd -- "$script_dir/.." && pwd)
source "$script_dir/profile-lib.sh"

profile= apply=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile) profile=${2:?}; shift 2 ;;
    --dry-run) apply=false; shift ;;
    --apply) apply=true; shift ;;
    *) echo "usage: create-template.sh --profile FILE [--dry-run|--apply]" >&2; exit 64 ;;
  esac
done

[[ -r "$profile" ]] || { echo "profile required" >&2; exit 66; }
require_no_placeholders "$profile"

template_vmid=$(yaml_value "$profile" appliance template_vmid)
template_name=$(yaml_value "$profile" appliance template_name)
node=$(yaml_value "$profile" instance node)
cores=$(yaml_value "$profile" instance cores)
memory=$(yaml_value "$profile" instance memory_mb)
machine=$(yaml_value "$profile" virtualization machine)
bridge=$(yaml_value "$profile" virtualization primary_bridge)
storage=$(yaml_value "$profile" storage pve_storage_id)
disk_size=$(yaml_value "$profile" storage os_disk_size_gib)
source_family=$(yaml_value "$profile" source family)
os_release=$(yaml_value "$profile" source release)
image_serial=$(yaml_value "$profile" source image_serial)
artifact=$(yaml_value "$profile" source artifact)
image_url=$(yaml_value "$profile" source url)
image_sha=$(yaml_value "$profile" source sha256)

[[ "$template_vmid" == 9320 ]] || { echo "this release expects template VMID 9320" >&2; exit 65; }
[[ "$template_name" == tpl-compute-ubuntu2604-* ]] || { echo "unexpected template name: $template_name" >&2; exit 65; }
[[ "$node" == hv-katra ]] || { echo "unexpected target node: $node" >&2; exit 65; }
[[ "$cores" =~ ^[1-9][0-9]*$ && "$memory" =~ ^[1-9][0-9]*$ && "$disk_size" =~ ^[1-9][0-9]*$ ]] \
  || { echo "invalid CPU, memory, or disk size" >&2; exit 65; }
[[ "$machine" == q35 && "$bridge" == vmbr0 && "$storage" == cuda-katra ]] \
  || { echo "unexpected virtualization/storage contract" >&2; exit 65; }
[[ "$source_family" == ubuntu-cloud-image && "$os_release" == 26.04 && -n "$image_serial" ]] \
  || { echo "template source must be the approved Ubuntu 26.04 cloud image" >&2; exit 65; }
[[ -n "$artifact" && "$image_url" == https://cloud-images.ubuntu.com/* ]] \
  || { echo "invalid Ubuntu image artifact/url" >&2; exit 65; }
[[ "$image_sha" =~ ^[0-9a-f]{64}$ ]] || { echo "invalid image SHA-256" >&2; exit 65; }

cache_dir="$root/.cache/template-images"
image_path="$cache_dir/$artifact"

render() {
  echo "# Phase 3: unbooted hardware-neutral Ubuntu 26.04 template"
  echo "# source serial: $image_serial"
  echo "# source sha256: $image_sha"
  printf '%q ' mkdir -p "$cache_dir"; echo
  printf '%q ' curl -fL --retry 3 --output "$image_path.part" "$image_url"; echo
  printf '%q ' sha256sum "$image_path.part"; echo
  echo "# verify sha256 equals $image_sha, then atomically rename to $image_path"
  printf '%q ' qm create "$template_vmid" --name "$template_name" --machine "$machine" --bios ovmf --cores "$cores" --memory "$memory" --scsihw virtio-scsi-single --net0 "virtio,bridge=$bridge" --serial0 socket --vga serial0 --ostype l26 --agent enabled=1; echo
  printf '%q ' qm disk import "$template_vmid" "$image_path" "$storage"; echo
  echo "# observe the resulting unusedX volume from: qm config $template_vmid"
  echo "# attach that observed volume as scsi0 with discard=on,ssd=1,iothread=1"
  printf '%q ' qm disk resize "$template_vmid" scsi0 "${disk_size}G"; echo
  printf '%q ' qm set "$template_vmid" --efidisk0 "$storage:1,efitype=4m,pre-enrolled-keys=1" --ide2 "$storage:cloudinit" --boot order=scsi0; echo
  printf '%q ' qm template "$template_vmid"; echo
  echo "# VM 9320 is never started before template conversion."
}

render
$apply || exit 0

require_proxmox_host
[[ $(hostname -s) == "$node" ]] || { echo "wrong host: $(hostname -s), expected $node" >&2; exit 69; }
qm status "$template_vmid" >/dev/null 2>&1 && { echo "VMID already exists: $template_vmid" >&2; exit 73; }
qm list | awk -v name="$template_name" 'NR>1 && $2 == name { found=1 } END { exit !found }' \
  && { echo "template name already exists: $template_name" >&2; exit 73; }
pvesm status --storage "$storage" | awk 'NR==2 && $3=="active" {ok=1} END {exit !ok}' \
  || { echo "storage is not active: $storage" >&2; exit 69; }
[[ -d "/sys/class/net/$bridge" && "$(cat "/sys/class/net/$bridge/operstate")" == up ]] \
  || { echo "bridge is not operational: $bridge" >&2; exit 69; }

available_kib=$(pvesm status --storage "$storage" | awk 'NR==2 {print $6}')
required_kib=$(( (disk_size + 4) * 1024 * 1024 ))
[[ "$available_kib" =~ ^[0-9]+$ ]] || { echo "could not determine free space on $storage" >&2; exit 69; }
(( available_kib >= required_kib )) || { echo "insufficient space on $storage" >&2; exit 69; }

command -v curl >/dev/null 2>&1 || { echo "curl is required and is not installed" >&2; exit 69; }
command -v sha256sum >/dev/null 2>&1 || { echo "sha256sum is required" >&2; exit 69; }

mkdir -p "$cache_dir"
if [[ -f "$image_path" ]]; then
  observed_sha=$(sha256sum "$image_path" | awk '{print $1}')
  [[ "$observed_sha" == "$image_sha" ]] || {
    echo "cached image hash mismatch: $image_path" >&2
    exit 69
  }
  echo "verified existing image: $image_path"
else
  tmp_image="$image_path.part"
  rm -f "$tmp_image"
  curl -fL --retry 3 --output "$tmp_image" "$image_url"
  observed_sha=$(sha256sum "$tmp_image" | awk '{print $1}')
  [[ "$observed_sha" == "$image_sha" ]] || {
    echo "downloaded image hash mismatch: expected $image_sha observed $observed_sha" >&2
    rm -f "$tmp_image"
    exit 69
  }
  mv "$tmp_image" "$image_path"
  echo "downloaded and verified image: $image_path"
fi

created=false
on_error() {
  rc=$?
  if $created; then
    echo "template construction failed after VM creation; preserving partial VM for evidence" >&2
    qm config "$template_vmid" >&2 || true
  fi
  exit "$rc"
}
trap on_error ERR

qm create "$template_vmid" --name "$template_name" --machine "$machine" --bios ovmf \
  --cores "$cores" --memory "$memory" --scsihw virtio-scsi-single \
  --net0 "virtio,bridge=$bridge" --serial0 socket --vga serial0 --ostype l26 --agent enabled=1
created=true

qm disk import "$template_vmid" "$image_path" "$storage"
imported=$(qm config "$template_vmid" | awk -F': ' '/^unused[0-9]+:/ {print $2; exit}')
[[ -n "$imported" ]] || { echo "import completed but no unused disk was observed" >&2; exit 69; }
[[ "$imported" == "$storage:"* ]] || { echo "imported disk is not on $storage: $imported" >&2; exit 69; }

qm set "$template_vmid" --scsi0 "$imported,discard=on,ssd=1,iothread=1"
qm disk resize "$template_vmid" scsi0 "${disk_size}G"
qm set "$template_vmid" \
  --efidisk0 "$storage:1,efitype=4m,pre-enrolled-keys=1" \
  --ide2 "$storage:cloudinit" \
  --boot order=scsi0

# The cloud image has never been started. Convert it directly into the reusable OS template.
qm template "$template_vmid"

config=$(qm config "$template_vmid")
grep -Fx 'template: 1' <<<"$config" >/dev/null || { echo "template flag missing after conversion" >&2; exit 69; }
grep -Eq "^scsi0: ${storage}:.*size=${disk_size}G" <<<"$config" || { echo "scsi0 is not the expected ${disk_size}G disk on $storage" >&2; exit 69; }
grep -Eq "^efidisk0: ${storage}:" <<<"$config" || { echo "EFI disk is not on $storage" >&2; exit 69; }
grep -Eq "^ide2: ${storage}:.*cloudinit" <<<"$config" || { echo "cloud-init disk is not on $storage" >&2; exit 69; }
grep -Eq "^net0: .*bridge=${bridge}" <<<"$config" || { echo "expected vmbr0 NIC missing" >&2; exit 69; }
! grep -Eq '^hostpci|^scsi1:|bridge=vmbr1|local-zfs:|^scsi0: local:|^efidisk0: local:|^ide2: local:' <<<"$config" \
  || { echo "forbidden GPU/model/boot-storage attachment found in template" >&2; exit 69; }

rm -f "$image_path"
trap - ERR

echo "template created and verified: $template_name (VMID $template_vmid)"
echo "source image sha256: $image_sha"
echo "VM 9320 was never started before template conversion"
