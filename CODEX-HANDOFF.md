# Codex handoff — hv-katra GPU compute appliance

## Scope

Continue the reusable GPU compute appliance on `hv-katra` from the accepted host
preparation state. Do not improvise storage, PCI identity, network identity, or
hardware profiles. Use the repository's reviewed profiles and live preflight.

## Accepted host state

- Phase 1 storage: **ACCEPTED**.
- Phase 2 VFIO/reboot validation: **ACCEPTED**.
- Proxmox VE: 9.2.2; kernel: 7.0.14-6-pve.
- `cuda-katra`: active LVM-thin on the exact approved 256 GiB SN5100 allocation.
- remaining SN5100 capacity: 675.5 GiB unpartitioned.
- `vmbr0`: operational at `192.168.10.21/24`.
- `vmbr1`: operational at `192.168.100.21/24`, MTU 9000.
- RTX 5070 Ti functions `01:00.0` and `01:00.1`: bound to `vfio-pci`.
- upstream root port `00:01.0`: host-owned by `pcieport`.

## Construction doctrine

The abandoned Phase 3A transitive-package-closure experiment is historical
evidence, not a deployment gate. Do not resume it.

For deployed guests use the proven appliance pattern: trusted OS/vendor sources,
bounded package simulation, refusal of dangerous removals, high-value top-level pins,
recorded installed versions, and live hardware acceptance. Do not require a complete
cryptographic lock of every transitive package before construction.

## Immediate Phase 3 — VM 9320 only

VM 9320 is the **unbooted hardware-neutral Ubuntu 26.04 OS template** for the modern
compute platform.

Use:

- `proxmox/hv-katra-template.yaml`
- `proxmox/create-template.sh`
- `docs/template-build.md`

Template contract:

- Ubuntu 26.04 LTS cloud image, Canonical release serial `20260612`
- accepted SHA-256 `0c9fb915bab0b36b361d3bf8aeae2115dda19d81a306656964de048033481670`
- VMID 9320
- name `tpl-compute-ubuntu2604-20260808`
- q35 + OVMF
- 8 vCPU
- 16384 MiB RAM
- 32 GiB root on `cuda-katra`
- EFI on `cuda-katra`
- cloud-init disk on `cuda-katra`
- `vmbr0` only
- no GPU
- no model disk
- no NVIDIA/AMD/Intel GPU software
- no CUDA or ROCm
- no cuda-compute checkout or BUILD
- no production identity

**VM 9320 must never be started before conversion to a template.** There is no guest
bootstrap and no sanitation step in Phase 3.

Before mutation verify:

- running on `hv-katra`;
- `cuda-katra` active with sufficient free space;
- VMID/name unused;
- `vmbr0` operational;
- existing VMs/containers in expected state;
- SN5100 partition boundary unchanged;
- accepted RTX 5070 Ti VFIO state unchanged.

Then run:

```bash
proxmox/create-template.sh \
  --profile proxmox/hv-katra-template.yaml \
  --dry-run

proxmox/create-template.sh \
  --profile proxmox/hv-katra-template.yaml \
  --apply
```

The builder must verify the exact cloud-image SHA-256, import it with existing
Proxmox tooling to `cuda-katra`, attach the observed imported volume as `scsi0`, resize
it to 32 GiB, create EFI/cloud-init disks on `cuda-katra`, and convert VM 9320
directly to a template.

After conversion prove:

- `template: 1`
- `scsi0` on `cuda-katra`, size 32 GiB
- EFI on `cuda-katra`
- cloud-init disk on `cuda-katra`
- `vmbr0` only
- no `hostpci*`
- no `scsi1`
- no `vmbr1`
- no disk on `local` or `local-zfs`
- VM 9320 was never started
- `cuda-katra`, SN5100 boundary, host bridges, guests, and VFIO remain healthy

Capture before/after host CPU/PCH/SN5100 telemetry using the already proven sysfs
method. Then STOP. Do not create VM 320 in the same play.

## Modern GPU profiles

- `config/profiles/nvidia-rtx5070ti/profile.yaml`
  - Ubuntu 26.04
  - CUDA 13.3
  - `sm_120`
  - NVIDIA open kernel modules
  - immediate reference deployment after Phase 3

- `config/profiles/amd-rx9070xt/profile.yaml`
  - Ubuntu 26.04
  - ROCm 7.14
  - `gfx1201`
  - design-stage until the RX 9070 XT is locally tested

A future Arc Pro B70 profile may use the Ubuntu 26.04 modern template when the B70 is
actually local. Do not perform B70-specific work now.

## Legacy GPU compatibility

`config/profiles/nvidia-p6000/profile.yaml` is legacy design-stage only. The Pascal
P6000 requires a separate Ubuntu 24.04 disposable root/template for CUDA 12.9 / R580
when it is actually tested. P6000 work does not block the current deployment.

## Reference VM 320 contract

When separately authorized after Phase 3 acceptance:

- VMID: 320
- hostname: `cuda-compute-katra`
- 8 vCPU / 16384 MiB RAM
- root: 32 GiB on `cuda-katra`
- data: 160 GiB on `cuda-katra`, label `cuda-models`, mount `/mnt/models`
- NIC 1: `vmbr0`, `192.168.10.92/24`, gateway `192.168.10.1`
- NIC 2: `vmbr1`, `192.168.100.92/24`, MTU 9000, no gateway
- DNS: `192.168.10.250`, `192.168.10.251`
- search domain: `home.arpa`
- logical GPU mapping: `gpu-compute-rtx5070ti`

The deployed clone, not VM 9320, receives `/srv/cuda-compute`, GPU-specific software,
the durable model disk, production network identity, and acceptance tests.

## Stop conditions

Stop on a genuine material mismatch: wrong disk/storage identity, VMID collision,
broken bridge, changed SN5100 boundary, unexpected PCI/VFIO state, image SHA mismatch,
package action later attempting to remove a protected stack, wrong GPU identity, or
inability to prove the selected compute backend.

Do not stop merely because the retired Phase 3A dependency-closure experiment was not
completed.
