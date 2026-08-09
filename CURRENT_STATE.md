# Current state

## 2026-08-08 accepted host state

Phase 1 storage is **ACCEPTED**. Phase 2 VFIO/reboot validation is **ACCEPTED**.
Phase 3 modern template construction is **ACCEPTED**.

The dedicated `cuda-katra` LVM-thin store occupies exactly the approved 256 GiB
partition on the Sandisk Optimus 5100; the remaining 675.5 GiB remains
unpartitioned. The RTX 5070 Ti compute/audio functions remain persistently bound to
`vfio-pci`, the upstream root port remains host-owned by `pcieport`, and both host
bridges remain healthy (`vmbr1` MTU 9000).

## Phase 3 accepted result

VM 9320 exists as the modern unbooted hardware-neutral Ubuntu 26.04 template:

- VMID: 9320
- name: `tpl-compute-ubuntu2604-20260808`
- Canonical cloud-image release serial: `20260612`
- verified image SHA-256: `0c9fb915bab0b36b361d3bf8aeae2115dda19d81a306656964de048033481670`
- q35 + OVMF
- 8 vCPU / 16 GiB RAM
- `scsi0`: `cuda-katra:base-9320-disk-0`, 32 GiB
- EFI disk: `cuda-katra`
- cloud-init disk: `cuda-katra`
- one NIC on `vmbr0`
- `template: 1`
- no GPU assignment
- no model/data disk
- no `vmbr1`
- no VM disk on `local` or `local-zfs`
- no raw NVMe assignment
- never booted before template conversion

The initial execution session disconnected while Proxmox was creating/importing the
thin LV. The underlying process continued normally. The journal later showed scsi0
attachment, resize, EFI/cloud-init creation, and successful `qm template 9320`
completion at 23:21:53. No retry, process termination, cleanup, or repair was required.

Post-construction LVM state was healthy: `base-9320-disk-0` exists as a 32 GiB thin LV,
`cuda-katra-thin` was Data% 0.86 / Meta% 10.64, monitoring was enabled, and no kernel
I/O or NVMe errors were observed.

## Construction doctrine

The earlier Phase 3A full transitive-package closure experiment remains historical
evidence only and is not a deployment prerequisite.

VM 9320 is intentionally just a reusable OS image. It contains no `cuda-compute`
checkout, BUILD record, vendor GPU driver/toolkit, Ollama, llama.cpp build, model disk,
production identity, or runtime evidence. There is no template guest bootstrap or
sanitation step.

For deployed guests use the proven appliance pattern: trusted OS/vendor sources,
bounded package simulation, refusal of dangerous removals, high-value top-level pins,
recorded installed versions, and live hardware acceptance.

## Phase 4 preparation status

The repository deployment surface for the RTX 5070 Ti reference VM is now implemented.

Authoritative inputs:

- `proxmox/hv-katra-rtx5070ti.yaml` — concrete non-secret VM 320 deployment profile;
- `proxmox/deploy-instance.sh` — standard Proxmox cloud-init deployment path;
- `tests/unit/deployment-contract.sh` — regression contract for the VM 320 profile;
- `docs/deployment.md` — operator deployment and first-boot boundary.

The old `proxmox/example-profile.yaml` is retired example material. The deployment no
longer depends on committed custom cloud-init snippets, Ubuntu ISO fields, repository
placeholders, or private deployment files. Operator SSH access is supplied at runtime
using an external SSH public-key file.

## GPU families

The modern Ubuntu 26.04 template is intended for:

- RTX 5070 Ti: Blackwell, CUDA 13.3, `sm_120`, NVIDIA open kernel modules.
- RX 9070 XT: RDNA4, ROCm 7.14, `gfx1201` (design-stage until locally tested).
- a future Arc Pro B70 profile may reuse this template when a B70 is local; no B70 work is in the current critical path.

The Quadro P6000 remains legacy compatibility only. Its Pascal CUDA 12.9 / R580
profile requires a separate Ubuntu 24.04 disposable root/template when actually
tested.

## Next executable boundary — create reference VM 320

The next phase is the live deployment of VM 320 on `hv-katra` with the RTX 5070 Ti:

- VMID: 320
- hostname/name: `cuda-compute-katra`
- 8 vCPU / 16 GiB RAM
- full clone from VM 9320, root remaining on `cuda-katra`
- model/data disk: 160 GiB on `cuda-katra`, future label `cuda-models`, future mount `/mnt/models`
- `192.168.10.92/24` on `vmbr0`, gateway `192.168.10.1`
- `192.168.100.92/24` on `vmbr1`, MTU 9000, no gateway
- DNS: `192.168.10.250`, `192.168.10.251`
- search domain: `home.arpa`
- logical GPU mapping: `gpu-compute-rtx5070ti`

Before mutation, run the repository regression tests and a complete deployment
dry-run with an operator-owned SSH public-key file. The live deployment may then clone,
configure, attach the logical GPU mapping, and start VM 320. Formatting the model disk,
transferring repository source, installing CUDA/NVIDIA software, and acceptance remain
separate post-boot gates.

Acceptance—not cloning or driver installation—promotes VM 320 into the reference
appliance.
