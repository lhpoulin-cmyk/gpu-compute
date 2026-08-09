# GPU swap model

`cuda-compute` treats the VM root disk as disposable and the model/data disk as
durable. Different GPU families receive fresh roots from the appropriate neutral OS
template instead of accumulating conflicting vendor stacks in one guest.

## Modern base

VM 9320 is an unbooted, hardware-neutral Ubuntu 26.04 cloud-image template. It
contains no GPU driver, CUDA toolkit, ROCm stack, Ollama installation, llama.cpp
build, cuda-compute checkout, model disk, GPU, or production identity.

Current modern profiles:

- RTX 5070 Ti / Blackwell: Ubuntu 26.04 + CUDA 13.3 + NVIDIA open kernel modules.
- Radeon RX 9070 XT / RDNA4: Ubuntu 26.04 + ROCm 7.14 + `gfx1201` (design-stage until locally tested).
- Arc Pro B70 may be added to the Ubuntu 26.04 family later, but no B70-specific implementation is part of the current Katra deployment.

## Legacy compatibility

The Quadro P6000 is Pascal legacy compatibility. Its CUDA 12.9 / R580 profile
requires a separate Ubuntu 24.04 disposable root/template when the P6000 is actually
tested. Do not force the modern 26.04 template to serve Pascal merely to make every
card share one OS image.

## Durable data boundary

The 160 GiB `cuda-models` virtual disk is the durable workload disk. It is distinct
from the 32 GiB OS/root disk and may be detached from a stopped instance and attached
to its replacement instance after explicit identity checks. Model weights and
accepted outputs do not need to be recopied merely because the GPU changes.

Never attach the same writable model disk to two running guests.

## Normal GPU change

1. Stop the existing compute VM and record its active hardware profile and model-disk identity.
2. Detach the model disk without deleting it.
3. Replace/reseat the physical GPU on `hv-katra`.
4. Re-run bounded host PCI/IOMMU/VFIO discovery and update the logical Proxmox PCI mapping.
5. Clone a fresh root from the correct neutral template for that GPU family.
6. Reattach the preserved model disk.
7. Attach the logical GPU mapping.
8. Boot the guest and materialize `/srv/cuda-compute` from the approved repository revision.
9. Run `bootstrap/install.sh` with the selected hardware profile.
10. Reboot when the selected driver stack requires it.
11. Run profile-specific smoke and acceptance tests before calling the appliance operational.

Do not normally convert an NVIDIA root into AMD ROCm, or a modern 26.04 root into a
legacy Pascal root. A fresh root is easier to reason about and keeps comparative
benchmark results cleaner.

## Current profiles

- `config/profiles/nvidia-rtx5070ti/profile.yaml` — immediate reference deployment.
- `config/profiles/amd-rx9070xt/profile.yaml` — modern design-stage profile.
- `config/profiles/nvidia-p6000/profile.yaml` — legacy design-stage profile requiring Ubuntu 24.04.

## Acceptance principle

A GPU is not accepted because its driver loads. Each profile must prove the intended
compute backend with a real workload and reject silent CPU fallback. Comparative
benchmarks should retain the same durable model/data disk, model artifact,
prompt/workload, and measurement method where practical.
