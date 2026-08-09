# Current state

## 2026-08-08 host state

Phase 1 storage is **ACCEPTED**. Phase 2 VFIO/reboot validation is **ACCEPTED**.
The dedicated `cuda-katra` LVM-thin store occupies exactly the approved 256 GiB
partition on the Sandisk Optimus 5100; the remaining 675.5 GiB remains
unpartitioned. The RTX 5070 Ti compute/audio functions are persistently bound to
`vfio-pci`, the upstream root port remains host-owned, and both host bridges
survived reboot (`vmbr1` remains MTU 9000).

No VM 9320 or VM 320 has yet been created by the template/deployment phases.

## Construction correction

The earlier Phase 3A attempt over-constrained normal package construction by
requiring a complete cryptographic lock of every transitive CUDA package before a
template could exist. That is no longer the appliance contract.

The repository now follows the proven appliance pattern used by the existing GPU
encode work:

- verify the base OS image;
- simulate bounded package transactions before applying them;
- refuse dangerous removals or unexpected stack replacement;
- use official vendor repositories;
- pin high-value top-level application/toolchain choices where useful;
- record the exact packages/versions actually installed;
- prove the real hardware path during instance acceptance.

The abandoned isolated snapshot/CUDA-closure experiment remains historical
evidence; it is not a prerequisite for VM 9320.

## Shared GPU architecture

VM 9320 is now a hardware-neutral **Ubuntu 24.04 LTS** template. Ubuntu 24.04 is
the common supported base for the current target profiles:

- RTX 5070 Ti: NVIDIA Blackwell, CUDA 13.3, `sm_120`, open kernel modules.
- RX 9070 XT: AMD RDNA4, ROCm, `gfx1201`.
- Quadro P6000: NVIDIA Pascal, CUDA 12.9, `sm_61`, proprietary R580 branch.

The template itself contains no vendor GPU driver, CUDA, ROCm, Ollama, llama.cpp,
GPU assignment, model disk, or production identity. GPU-specific software is
installed only after a clone receives an actual GPU profile.

The 32 GiB root disk is disposable. The 160 GiB model/data virtual disk is the
durable workload boundary and can be preserved across an explicitly reviewed GPU
swap/rebuild. See `docs/gpu-swap.md`.

## Current reference deployment

The immediate reference target remains VM 320 on `hv-katra` with the RTX 5070 Ti:

- 8 vCPU / 16 GiB RAM
- root: 32 GiB on `cuda-katra`
- model/data: 160 GiB on `cuda-katra`, label `cuda-models`, mounted `/mnt/models`
- `192.168.10.92/24` on `vmbr0`
- `192.168.100.92/24` on `vmbr1`, MTU 9000
- default route only through `192.168.10.1`

## Next executable boundary

Phase 3 is now the creation of the generic VM 9320 Ubuntu 24.04 template only.
It does not install a GPU vendor stack and therefore does not require CUDA/ROCm
package closure work.

After template acceptance, the RTX 5070 Ti clone/deployment is the next phase.
RX 9070 XT and P6000 profiles are included now so later card swaps use the same
template/data-disk pattern instead of growing separate appliance designs.
