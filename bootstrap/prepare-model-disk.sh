#!/usr/bin/env bash
set -Eeuo pipefail

apply=false
requested_device=
label=cuda-models
mountpoint=/mnt/models
expected_bytes=$((160 * 1024 * 1024 * 1024))
tolerance_bytes=$((1 * 1024 * 1024 * 1024))

while [[ $# -gt 0 ]]; do
  case "$1" in
    --device) requested_device=${2:?}; shift 2 ;;
    --dry-run) apply=false; shift ;;
    --apply) apply=true; shift ;;
    *) echo "usage: prepare-model-disk.sh [--device /dev/DEVICE] [--dry-run|--apply]" >&2; exit 64 ;;
  esac
done

if findmnt -M "$mountpoint" -n >/dev/null 2>&1; then
  source_dev=$(findmnt -M "$mountpoint" -no SOURCE)
  current_label=$(lsblk -no LABEL "$source_dev" 2>/dev/null | head -1 | xargs)
  [[ "$current_label" == "$label" ]] || {
    echo "$mountpoint is already mounted from an unexpected source: $source_dev label=$current_label" >&2
    exit 69
  }
  echo "$mountpoint already mounted from $source_dev with label $label"
  exit 0
fi

root_source=$(findmnt -M / -no SOURCE)
root_parent=$(lsblk -no PKNAME "$root_source" 2>/dev/null | head -1 | xargs)
[[ -n "$root_parent" ]] && root_parent="/dev/$root_parent"

candidates=()
while read -r name size type; do
  [[ "$type" == disk ]] || continue
  dev="/dev/$name"
  [[ "$dev" == "$root_parent" ]] && continue
  delta=$(( size > expected_bytes ? size - expected_bytes : expected_bytes - size ))
  (( delta <= tolerance_bytes )) || continue
  candidates+=("$dev")
done < <(lsblk -bdn -o NAME,SIZE,TYPE)

if [[ -n "$requested_device" ]]; then
  [[ -b "$requested_device" ]] || { echo "requested device is not a block device: $requested_device" >&2; exit 66; }
  found=false
  for dev in "${candidates[@]}"; do [[ "$dev" == "$requested_device" ]] && found=true; done
  $found || { echo "requested device does not match the isolated 160 GiB non-root candidate: $requested_device" >&2; exit 69; }
  device="$requested_device"
else
  [[ ${#candidates[@]} -eq 1 ]] || {
    echo "expected exactly one unambiguous ~160 GiB non-root disk; found ${#candidates[@]}: ${candidates[*]:-none}" >&2
    exit 69
  }
  device=${candidates[0]}
fi

children=$(lsblk -nrpo NAME "$device" | tail -n +2)
[[ -z "$children" ]] || { echo "refusing disk with child partitions/devices: $device" >&2; printf '%s\n' "$children" >&2; exit 69; }
findmnt -S "$device" -n >/dev/null 2>&1 && { echo "refusing mounted device: $device" >&2; exit 69; }

signatures=$(wipefs -n "$device" 2>/dev/null || true)
[[ -z "$signatures" ]] || { echo "refusing device with existing signatures: $device" >&2; printf '%s\n' "$signatures" >&2; exit 69; }

size=$(blockdev --getsize64 "$device")
echo "model disk candidate: $device"
echo "size_bytes: $size"
echo "root source: $root_source"
echo "planned filesystem: ext4 LABEL=$label"
echo "planned mount: $mountpoint"

if ! $apply; then
  echo "dry-run: no disk mutation"
  exit 0
fi

[[ $EUID -eq 0 ]] || { echo "apply requires root" >&2; exit 77; }
command -v mkfs.ext4 >/dev/null 2>&1 || { echo "mkfs.ext4 not found" >&2; exit 69; }

mkfs.ext4 -L "$label" "$device"
install -d -m 0755 "$mountpoint"

fstab_line="LABEL=$label $mountpoint ext4 defaults,nofail 0 2"
if ! grep -Eq "^[^#]*[[:space:]]${mountpoint//\//\/}[[:space:]]" /etc/fstab; then
  printf '%s\n' "$fstab_line" >> /etc/fstab
fi
mount "$mountpoint"

findmnt -M "$mountpoint" -n >/dev/null || { echo "model mount failed" >&2; exit 69; }
mounted_source=$(findmnt -M "$mountpoint" -no SOURCE)
mounted_fstype=$(findmnt -M "$mountpoint" -no FSTYPE)
[[ "$mounted_fstype" == ext4 ]] || { echo "unexpected model filesystem: $mounted_fstype" >&2; exit 69; }
[[ "$(lsblk -no LABEL "$device" | xargs)" == "$label" ]] || { echo "model label verification failed" >&2; exit 69; }

echo "model disk prepared: $device -> $mountpoint ($mounted_source, $mounted_fstype, LABEL=$label)"
