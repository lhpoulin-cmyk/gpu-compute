# GPU swap model

`cuda-compute` treats the VM root disk as disposable and the model/data disk as durable.
This is intentional: NVIDIA Blackwell, NVIDIA Pascal, and AMD RDNA4 require different
userspace/driver stacks, so in-place vendor-stack mutation is not the normal path.

## Common base

VM 9320 is a hardware-neutral Ubuntu 24.04 LTS template. It contains no GPU driver,
CUDA toolkit, ROCm stack, Ollama installation, llama.cpp build, model disk, GPU,
or production identity. Ubuntu 24.04 is the common supported base for the current
profiles:

- RTX 5070 Ti / Blackwell: CUDA 13.3 + NVIDIA open kernel modules.
- Quadro P6000 / Pascal: CUDA 12.9 + NVIDIA R580 proprietary kernel modules.
- Radeon RX 9070 XT / RDNA4: ROCm on `gfx1201`.

The hardware-neutral template is built once and reused for all three.

## Durable data boundary

The 160 GiB `cuda-models` virtual disk is the durable workload disk. It is distinct
from the 32 GiB OS/root disk and may be detached from a stopped instance and attached
to its replacement instance after explicit identity checks. Model weights and accepted
outputs do not need to be recopied merely because the GPU vendor changes.

Never attach the same writable model disk to two running guests.

## Normal GPU change

1. Stop the existing compute VM and record its active hardware profile and model-disk identity.
2. Detach the model disk without deleting it.
3. Replace/reseat the physical GPU on `hv-katra`.
4. Re-run the bounded host PCI/IOMMU/VFIO discovery and update the logical Proxmox PCI mapping.
5. Clone a fresh 32 GiB root from VM 9320.
6. Reattach the preserved model disk.
7. Attach the logical GPU mapping.
8. Boot the guest and run `bootstrap/install.sh` with the selected hardware profile.
9. Reboot when the selected driver stack requires it.
10. Run profile-specific smoke and acceptance tests before calling the appliance operational.

Do not attempt to convert an NVIDIA CUDA root into an AMD ROCm root or vice versa as
the default swap procedure. A fresh root is faster to reason about, easier to roll back,
and prevents stale vendor packages from contaminating benchmark results.

## Current profiles

- `config/profiles/nvidia-rtx5070ti/profile.yaml`
- `config/profiles/nvidia-p6000/profile.yaml`
- `config/profiles/amd-rx9070xt/profile.yaml`

Profiles own guest software expectations. The host-side deployment profile owns the
physical PCI mapping and may change when a card is physically swapped.

## Acceptance principle

A GPU is not accepted because its driver loads. Each profile must prove the intended
compute backend with a real workload and reject silent CPU fallback. Comparative
benchmarks should retain the same model/data disk, model artifact, prompt/workload,
and measurement method where practical.
