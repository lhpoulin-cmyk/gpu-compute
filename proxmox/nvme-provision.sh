#!/usr/bin/env bash
set -Eeuo pipefail

device=
size=256G
storage_id=cuda-katra
vg=cuda-katra-vg
thinpool=cuda-katra-thin
expected_serial=
apply=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --device)          device=${2:?}; shift 2 ;;
    --size)            size=${2:?}; shift 2 ;;
    --storage-id)      storage_id=${2:?}; shift 2 ;;
    --vg)              vg=${2:?}; shift 2 ;;
    --thinpool)        thinpool=${2:?}; shift 2 ;;
    --expected-serial) expected_serial=${2:?}; shift 2 ;;
    --dry-run)         apply=false; shift ;;
    --apply)           apply=true; shift ;;
    *)
      echo "usage: nvme-provision.sh --device DEVICE --expected-serial SERIAL [--size 256G] [--storage-id cuda-katra] [--vg cuda-katra-vg] [--thinpool cuda-katra-thin] [--dry-run|--apply]" >&2
      exit 64
      ;;
  esac
done

[[ -n "$device" ]] || { echo "--device is required" >&2; exit 64; }
[[ -n "$expected_serial" ]] || { echo "--expected-serial is required" >&2; exit 64; }

real_device=$(readlink -f "$device")
[[ -b "$real_device" ]] || { echo "not a block device: $real_device ($device)" >&2; exit 66; }
[[ "$(lsblk -dn -o TYPE "$real_device")" == disk ]] || { echo "device must be a whole disk" >&2; exit 65; }

name=$(basename "$real_device")
serial=$(lsblk -dn -o SERIAL "$real_device" | xargs)
model=$(lsblk -dn -o MODEL "$real_device" | xargs)
[[ "$serial" == "$expected_serial" ]] || {
  echo "serial mismatch: expected $expected_serial, observed ${serial:-<none>}" >&2
  exit 73
}

if [[ "$name" == nvme* ]]; then
  part_device="${real_device}p1"
else
  part_device="${real_device}1"
fi

echo "# target device: $real_device"
echo "# model:         $model"
echo "# serial:        $serial"
echo "# partition:     $part_device ($size, GPT type 8e00)"
echo "# VG:            $vg"
echo "# thin pool:     $thinpool (95% VG; remainder reserved)"
echo "# Proxmox ID:    $storage_id"
echo "# VM disks:      template/root + VM 320 root + VM 320 model disk"
echo

echo "sgdisk --new=1:0:+$size --typecode=1:8e00 --change-name=1:cuda-katra-lvm $real_device"
echo "partprobe $real_device"
echo "pvcreate $part_device"
echo "vgcreate $vg $part_device"
echo "lvcreate --type thin-pool -l 95%VG -n $thinpool $vg"
echo "pvesm add lvmthin $storage_id --vgname $vg --thinpool $thinpool --content images"

$apply || { echo; echo "dry-run: storage not modified"; exit 0; }

for cmd in sgdisk partprobe pvcreate vgcreate lvcreate pvesm; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "missing required command: $cmd" >&2; exit 69; }
done

# Destructive preflight: refuse anything except the explicitly identified blank disk.
existing_parts=$(lsblk -nr -o TYPE "$real_device" | awk '$1=="part"{n++} END{print n+0}')
[[ "$existing_parts" -eq 0 ]] || {
  echo "device already has partitions; refusing destructive provisioning" >&2
  lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS,MODEL,SERIAL "$real_device" >&2
  exit 73
}

[[ -z "$(lsblk -dn -o FSTYPE "$real_device" | xargs)" ]] || {
  echo "whole-disk filesystem signature detected; refusing" >&2
  exit 73
}

if wipefs -n "$real_device" 2>/dev/null | grep -q .; then
  echo "wipefs reports an existing signature; refusing" >&2
  wipefs -n "$real_device" >&2 || true
  exit 73
fi

if lsblk -nr -o MOUNTPOINTS "$real_device" | grep -q '[^[:space:]]'; then
  echo "device or child is mounted; refusing" >&2
  exit 73
fi

if [[ -d "/sys/class/block/$name/holders" ]] && find "/sys/class/block/$name/holders" -mindepth 1 -maxdepth 1 | grep -q .; then
  echo "device has active holders; refusing" >&2
  find "/sys/class/block/$name/holders" -mindepth 1 -maxdepth 1 -printf '%f\n' >&2
  exit 73
fi

if pvs --noheadings -o pv_name 2>/dev/null | awk '{$1=$1};1' | grep -Fxq "$real_device"; then
  echo "device is already an LVM PV; refusing" >&2
  exit 73
fi

pvesm status --storage "$storage_id" >/dev/null 2>&1 && {
  echo "Proxmox storage ID already exists: $storage_id" >&2
  exit 73
}

sgdisk --new=1:0:+"$size" --typecode=1:8e00 --change-name=1:cuda-katra-lvm "$real_device"
partprobe "$real_device"
udevadm settle
[[ -b "$part_device" ]] || { echo "partition did not appear: $part_device" >&2; exit 69; }

pvcreate "$part_device"
vgcreate "$vg" "$part_device"
lvcreate --type thin-pool -l 95%VG -n "$thinpool" "$vg"
pvesm add lvmthin "$storage_id" --vgname "$vg" --thinpool "$thinpool" --content images

echo
echo "provisioned Proxmox LVM-thin storage: $storage_id"
pvesm status --storage "$storage_id"
echo "No filesystem was created on the host partition and no raw NVMe is passed through to VM 320."
