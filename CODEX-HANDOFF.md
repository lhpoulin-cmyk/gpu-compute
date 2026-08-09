# Codex handoff — hv-katra GPU compute appliance

## Accepted state

The following phases are complete and accepted:

- Phase 1 storage: **ACCEPTED**
- Phase 2 VFIO/reboot validation: **ACCEPTED**
- Phase 3 Ubuntu 26.04 template construction: **ACCEPTED**

`cuda-katra` remains the dedicated LVM-thin store on the approved first 256 GiB of
the Sandisk Optimus 5100. The remaining ~675.5 GiB remains unpartitioned. `vmbr0`
and `vmbr1` are healthy; `vmbr1` is MTU 9000. RTX 5070 Ti compute/audio functions
remain bound to `vfio-pci`; the upstream root port remains host-owned by `pcieport`.

## Accepted VM 9320

VM 9320 is the reusable modern OS template:

- name: `tpl-compute-ubuntu2604-20260808`
- Ubuntu 26.04 Canonical cloud image, release serial `20260612`
- verified SHA-256: `0c9fb915bab0b36b361d3bf8aeae2115dda19d81a306656964de048033481670`
- q35 + OVMF
- 8 vCPU / 16384 MiB RAM
- `scsi0`: 32 GiB on `cuda-katra`
- EFI disk on `cuda-katra`
- cloud-init disk on `cuda-katra`
- one `vmbr0` NIC
- `template: 1`
- no GPU, model disk, `vmbr1`, production identity, local/local-zfs VM disk, or raw NVMe
- never booted before template conversion

The apparent thin-LV stall during construction was a disconnected execution session.
Proxmox continued and completed the template normally; no retry or repair was needed.

## Construction doctrine

Do not resume the retired Phase 3A full transitive-package closure experiment.
For deployed guests use trusted Ubuntu/vendor sources, bounded package simulations,
refusal of dangerous removals, high-value top-level pins, exact installed-version
recording, and live hardware acceptance.

VM 9320 is only an OS template. It intentionally contains no `cuda-compute` checkout,
BUILD record, vendor GPU stack, Ollama, llama.cpp build, model disk, or runtime state.

## Next boundary — RTX 5070 Ti reference VM 320

The next implementation phase is VM 320 with the RTX 5070 Ti.

Target contract:

- VMID: 320
- hostname/name: `cuda-compute-katra`
- source: full clone of VM 9320
- node: `hv-katra`
- 8 vCPU / 16384 MiB RAM
- root remains entirely on `cuda-katra`
- second virtual disk: 160 GiB on `cuda-katra`
- model filesystem label: `cuda-models`
- mount: `/mnt/models`
- NIC 1: `vmbr0`, `192.168.10.92/24`, gateway `192.168.10.1`
- NIC 2: `vmbr1`, `192.168.100.92/24`, MTU 9000, no gateway
- DNS: `192.168.10.250`, `192.168.10.251`
- search domain: `home.arpa`
- logical PCI mapping: `gpu-compute-rtx5070ti`
- hardware profile: `config/profiles/nvidia-rtx5070ti/profile.yaml`

The RTX 5070 Ti profile requires Ubuntu 26.04, NVIDIA `ubuntu2604`, CUDA 13.3,
compute capability 12.0, and NVIDIA open kernel modules.

## Required Phase 4 preparation

Before executing VM 320 deployment, review and correct the deployment surface itself.
Do **not** blindly execute the old `proxmox/example-profile.yaml`: it is example/stale
input and still contains placeholder/private-profile concepts.

Phase 4 preparation must produce one reviewed concrete hv-katra deployment profile and
ensure `proxmox/deploy-instance.sh` matches the accepted VM 9320/cloud-init design.
Secrets or private SSH credentials must not be committed. Runtime operator SSH public
key input may remain external.

The preferred deployment pattern is:

1. preflight VMID/name/template/storage/bridges/GPU mapping;
2. full clone 9320 -> 320 on `cuda-katra`;
3. configure CPU/RAM and both NICs;
4. create the 160 GiB model virtual disk on `cuda-katra`;
5. apply cloud-init network/operator access without embedding secrets in Git;
6. attach logical RTX 5070 Ti mapping;
7. boot VM 320;
8. verify Ubuntu 26.04/network/GPU visibility;
9. prepare and mount the model disk;
10. transfer the current repository source into `/srv/cuda-compute` without placing GitHub private credentials in the guest;
11. run bounded RTX 5070 Ti bootstrap/package simulation and installation;
12. reboot if required;
13. run smoke and hardware acceptance;
14. finalize instance state only after acceptance passes.

Do not mix RX 9070 XT, P6000, or B70 implementation into this reference deployment.

## Other GPU profiles

- RX 9070 XT: Ubuntu 26.04 / ROCm 7.14 / `gfx1201`; design-stage until local testing.
- future Arc Pro B70: may use the modern Ubuntu 26.04 template when a B70 is local; no current work required.
- Quadro P6000: legacy Ubuntu 24.04 disposable root/template only when actually tested.

## Stop conditions

Stop on genuine material mismatch: wrong template/storage identity, VMID/name collision,
broken bridge, changed SN5100 boundary, missing/incorrect PCI mapping, unexpected GPU
identity, unsafe package transaction, inability to establish intended network identity,
model-disk ambiguity, or inability to prove GPU-backed compute without CPU fallback.
