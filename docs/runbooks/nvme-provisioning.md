# Runbook: Dedicated CUDA Proxmox Storage (SN5100)

**Host**: `hv-katra` (`192.168.10.21`)  
**Observed device**: `nvme0n1` — Sandisk Optimus 5100 1TB, serial `26100U800434`  
**Observed by-id**: `nvme-Sandisk_Optimus_5100_1TB_26100U800434`  
**Evidence date**: 2026-08-08  
**Goal**: create a 256 GiB GPT partition and expose it to Proxmox as dedicated LVM-thin storage `cuda-katra`.

This replaces the old raw-partition passthrough design. The host partition is an LVM PV; VM 9320 and VM 320 receive normal virtual disks from the resulting Proxmox storage.

## Evidence-backed starting point

The 2026-08-08 Lifetap refresh observed the SN5100 as a 931.5 GiB NVMe with no partitions and no filesystem. The same capture observed no `cuda-katra` Proxmox storage backend. Destructive apply still requires a just-in-time live preflight; historical evidence alone is not authorization to overwrite a device.

## Dry run

```bash
proxmox/nvme-provision.sh \
  --device /dev/disk/by-id/nvme-Sandisk_Optimus_5100_1TB_26100U800434 \
  --expected-serial 26100U800434 \
  --size 256G \
  --storage-id cuda-katra \
  --vg cuda-katra-vg \
  --thinpool cuda-katra-thin \
  --dry-run
```

The script verifies the exact serial and prints the intended GPT/LVM/Proxmox operations.

## Apply

```bash
proxmox/nvme-provision.sh \
  --device /dev/disk/by-id/nvme-Sandisk_Optimus_5100_1TB_26100U800434 \
  --expected-serial 26100U800434 \
  --size 256G \
  --storage-id cuda-katra \
  --vg cuda-katra-vg \
  --thinpool cuda-katra-thin \
  --apply
```

Apply fails closed if the disk has partitions, filesystem signatures, mounts, holders, an existing LVM role, a serial mismatch, or a conflicting Proxmox storage ID.

## Resulting topology

```text
SN5100 1TB
└── GPT partition 1: 256 GiB, LVM PV
    └── cuda-katra-vg
        └── cuda-katra-thin (95% of VG)
            ├── VM 9320 root/EFI/cloud-init: 32 GiB root
            ├── VM 320 root/EFI/cloud-init: 64 GiB root
            └── VM 320 model disk: 160 GiB virtual disk
```

The remaining space in the VG is deliberate emergency headroom. The remaining
~675 GiB of the physical SN5100 is left unpartitioned and outside this
provisioning play's authorization; it may not be changed without a separate
explicit operator play.

## Guest model disk

VM 320 receives a second normal Proxmox virtual disk (`scsi1`) from `cuda-katra`; the host NVMe partition is never passed through.

Inside VM 320, identify the blank disk by size and attachment before formatting. Do not assume `/dev/sdb` without verifying `lsblk`.

```bash
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS,MODEL,SERIAL
```

After positively identifying the 160 GiB blank `scsi1` disk:

```bash
sudo mkfs.ext4 -L cuda-models /dev/VERIFIED_DEVICE
sudo mkdir -p /mnt/models
echo 'LABEL=cuda-models /mnt/models ext4 defaults,noatime 0 2' | sudo tee -a /etc/fstab
sudo mount /mnt/models
findmnt -M /mnt/models
```

Then run the normal instance bootstrap. `bootstrap/workspace.sh` fails closed unless `/mnt/models` is mounted. Template mode explicitly skips model-storage creation.

## Template retention

VM 9320 is retained for 90 days after VM 320 deployment/acceptance. Deletion is an explicit operator action; no automatic timer removes it.
