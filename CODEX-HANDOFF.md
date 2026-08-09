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

Use the proven appliance construction pattern:

1. verified Ubuntu image;
2. dry-run/simulate package actions;
3. refuse dangerous removals or unexpected replacements;
4. use official Ubuntu/vendor repositories;
5. pin high-value top-level versions/branches where the profile requires it;
6. record exact installed package versions;
7. prove the hardware path with live acceptance.

Do not require a cryptographic lock of every transitive Ubuntu/CUDA/ROCm package
before constructing the template.

## Hardware-neutral template

VM 9320 is the shared template for current GPU profiles:

- RTX 5070 Ti / Blackwell
- RX 9070 XT / RDNA4
- Quadro P6000 / Pascal

Template contract:

- Ubuntu 24.04 LTS
- VMID 9320
- name `tpl-compute-ubuntu2404-20260808`
- 8 vCPU
- 16384 MiB RAM
- 32 GiB root on `cuda-katra`
- `vmbr0` only
- no GPU
- no model disk
- no NVIDIA/AMD GPU driver
- no CUDA
- no ROCm
- no Ollama
- no llama.cpp build
- no production identity

Use:

- `proxmox/hv-katra-template.yaml`
- `config/profiles/generic/profile.yaml`
- `docs/template-build.md`

Template bootstrap installs only common guest/build prerequisites and the
workspace. Sanitize, shut down, then convert VM 9320 to a Proxmox template.
Preserve `BUILD`.

## GPU profiles

The current profiles are:

- `config/profiles/nvidia-rtx5070ti/profile.yaml`
  - CUDA 13.3
  - `sm_120`
  - NVIDIA open kernel modules
- `config/profiles/amd-rx9070xt/profile.yaml`
  - ROCm
  - `gfx1201`
- `config/profiles/nvidia-p6000/profile.yaml`
  - CUDA 12.9
  - `sm_61`
  - proprietary NVIDIA R580 branch

The immediate reference deployment remains RTX 5070 Ti. The other two profiles
are included now to preserve one template/rebuild model rather than create three
separate appliance designs.

## GPU swap doctrine

Do not normally convert an installed root filesystem from one GPU vendor stack to
another. The root disk is disposable; the 160 GiB model/data disk is durable.
For a GPU change, stop the VM, preserve/detach the model disk, update host
PCI/VFIO/resource mapping under an authorized host play, clone a fresh root from
9320, reattach the model disk, install the selected profile, and rerun acceptance.
See `docs/gpu-swap.md`.

## Immediate next phase — VM 9320 only

Preflight live state, then build the generic Ubuntu 24.04 VM 9320 template.
This phase may acquire and verify an official Canonical Ubuntu 24.04 cloud image
or installer artifact and use normal Proxmox image/import tooling already present
on the host. Do not install a Debian `qemu-utils` package that would replace or
remove the Proxmox virtualization stack.

Before mutation verify:

- `cuda-katra` active and healthy;
- VMID 9320 unused;
- root storage remains `cuda-katra`;
- bridges healthy;
- existing VMs/containers healthy;
- SN5100 partition boundary unchanged;
- GPU remains parked under VFIO.

Build VM 9320 exactly to the template contract, run generic template bootstrap,
sanitize it, shut it down, convert it to a template, and verify the final `qm
config` contains no GPU/model disk and no VM disk on host boot storage.

Then STOP.

Do not deploy VM 320 in the same play.

## Reference VM 320 contract

When separately authorized after template acceptance:

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

Acceptance, not cloning or driver installation, promotes the appliance.

## Stop conditions

Stop on a real material mismatch: wrong disk/storage identity, VMID collision,
unexpected PCI endpoint/group, broken bridge, package action that removes a
protected virtualization/guest stack, wrong GPU identity, missing model-disk
identity, or inability to prove the intended compute backend.

Do not stop merely because a harmless construction tool is outside the repository
workspace or because a previous over-constrained provenance experiment was not
completed.
