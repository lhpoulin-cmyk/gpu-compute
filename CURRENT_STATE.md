# Current state

## 2026-08-08 host state

Phase 1 storage is **ACCEPTED**. Phase 2 VFIO/reboot validation is **ACCEPTED**.
The dedicated `cuda-katra` LVM-thin store occupies exactly the approved 256 GiB
partition on the Sandisk Optimus 5100; the remaining 675.5 GiB remains
unpartitioned. The RTX 5070 Ti compute/audio functions are persistently bound to
`vfio-pci`, the upstream root port remains host-owned, and both host bridges survived
reboot (`vmbr1` remains MTU 9000).

No VM 9320 or VM 320 has yet been created by the template/deployment phases.

## Construction correction

The earlier Phase 3A attempt over-constrained normal package construction by
requiring a complete cryptographic lock of every transitive CUDA package before a
template could exist. That experiment is historical evidence only and is **not** a
deployment prerequisite.

The repository now follows the proven appliance pattern:

- verify the base OS image;
- use bounded package simulations before guest package mutation;
- refuse dangerous removals or unexpected stack replacement;
- use official vendor repositories;
- pin high-value top-level toolchain/application choices where useful;
- record exact installed versions;
- prove the real hardware path during instance acceptance.

## Modern OS template

Phase 3 now creates VM 9320 as an **unbooted, hardware-neutral Ubuntu 26.04 cloud-image template**.

VM 9320 contract:

- VMID: 9320
- name: `tpl-compute-ubuntu2604-20260808`
- Canonical cloud image serial: `20260612`
- accepted image SHA-256: `0c9fb915bab0b36b361d3bf8aeae2115dda19d81a306656964de048033481670`
- q35 + OVMF
- 8 vCPU / 16 GiB RAM
- 32 GiB root, EFI, and cloud-init disks entirely on `cuda-katra`
- `vmbr0` only
- no GPU
- no model disk
- no vendor driver/toolkit
- no cuda-compute checkout
- never booted before template conversion

Because the Canonical cloud image is converted directly into a Proxmox template,
Phase 3 has **no guest bootstrap and no sanitation step**.

## GPU families

The modern Ubuntu 26.04 template is intended for:

- RTX 5070 Ti: Blackwell, CUDA 13.3, `sm_120`, NVIDIA open kernel modules.
- RX 9070 XT: RDNA4, ROCm 7.14, `gfx1201` (design-stage until locally tested).
- a future Arc Pro B70 profile may reuse this modern template when a B70 is local; no B70 implementation is in the current critical path.

The Quadro P6000 remains legacy compatibility only. Its Pascal CUDA 12.9 / R580
profile requires a separate Ubuntu 24.04 disposable root/template when it is actually
tested and does not block the modern deployment.

## Current reference deployment

The immediate target after template acceptance remains VM 320 on `hv-katra` with the
RTX 5070 Ti:

- 8 vCPU / 16 GiB RAM
- root: 32 GiB on `cuda-katra`
- model/data: 160 GiB on `cuda-katra`, label `cuda-models`, mounted `/mnt/models`
- `192.168.10.92/24` on `vmbr0`
- `192.168.100.92/24` on `vmbr1`, MTU 9000
- default route only through `192.168.10.1`

## Next executable boundary

The next executable boundary is **Phase 3 only**: run the reviewed
`proxmox/create-template.sh` against `proxmox/hv-katra-template.yaml`, verify the
Ubuntu image hash, import the image to `cuda-katra`, convert VM 9320 directly to a
template without booting it, verify host/storage/VFIO health, and stop.

Only after Phase 3 acceptance should VM 320 be created and the RTX 5070 Ti stack be
installed and accepted.
