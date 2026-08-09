# Template Build — VM 9320

VM 9320 is the temporary, hardware-neutral **Ubuntu 26.04** operating-system
template for the modern compute platform. It lives entirely on `cuda-katra`, not
on the hv-katra boot pool, and is retained for 90 days after the first accepted
VM 320 deployment unless the operator explicitly changes that policy.

## Scope

VM 9320 is intentionally only an OS template. It is not a partially configured
compute appliance and it is never booted before conversion to a Proxmox template.

It contains no:

- GPU passthrough
- NVIDIA or AMD driver
- CUDA or ROCm toolkit
- Ollama or llama.cpp build
- cuda-compute checkout or BUILD file
- model/data disk
- production IP identity
- secrets or runtime evidence

GPU-specific software belongs on the deployed clone after a real GPU profile is
selected.

## Modern template contract

- VMID: `9320`
- name: `tpl-compute-ubuntu2604-20260808`
- OS image: Canonical Ubuntu 26.04 cloud image, serial `20260612`
- image: `ubuntu-26.04-server-cloudimg-amd64.img`
- accepted SHA-256:
  `0c9fb915bab0b36b361d3bf8aeae2115dda19d81a306656964de048033481670`
- q35 + OVMF
- 8 vCPU
- 16384 MiB RAM
- root disk: 32 GiB on `cuda-katra`
- EFI disk: `cuda-katra`
- cloud-init disk: `cuda-katra`
- one VirtIO NIC on `vmbr0`
- no `vmbr1`
- no GPU
- no model disk

The Canonical image provenance/signature verification was completed during the
2026-08-08 construction discovery. Phase 3 recomputes the accepted SHA-256 before
import; it does not reopen the retired transitive-package-lock experiment.

## Build

On `hv-katra`:

```bash
cd /srv/cuda-compute

proxmox/create-template.sh \
  --profile proxmox/hv-katra-template.yaml \
  --dry-run

proxmox/create-template.sh \
  --profile proxmox/hv-katra-template.yaml \
  --apply
```

The builder downloads or reuses the exact accepted cloud image, verifies its
SHA-256, creates VM 9320, imports the image with Proxmox `qm disk import`, attaches
that observed imported volume as `scsi0`, resizes it to 32 GiB, creates EFI and
cloud-init disks on `cuda-katra`, and converts the VM directly to a template.

**VM 9320 is not started.** Therefore there is no guest bootstrap and no sanitation
step in Phase 3.

## Acceptance

After conversion, verify `qm config 9320` shows:

- `template: 1`
- `scsi0` on `cuda-katra`, size 32 GiB
- `efidisk0` on `cuda-katra`
- cloud-init disk on `cuda-katra`
- only `vmbr0`
- no `hostpci*`
- no `scsi1`
- no `vmbr1`
- no VM disk on `local` or `local-zfs`

Also verify `cuda-katra`, the SN5100 partition boundary, host bridges, existing
guests, and the accepted VFIO state remain healthy.

## GPU families

VM 9320 is the modern Ubuntu 26.04 root for the RTX 5070 Ti and RX 9070 XT, and
may later serve an Arc Pro B70 profile when a B70 is actually local to the test
platform. The Quadro P6000 is Pascal legacy compatibility and requires a separate
Ubuntu 24.04 root/template when it is actually tested.
