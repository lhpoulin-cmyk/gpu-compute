# Helix-ARPA GPU Compute Appliance

This repository is the source of truth for a reusable GPU compute appliance on
`hv-katra`. It contains policy, bootstrap logic, hardware profiles, operator
commands, validation tests, evidence references, and reviewed Proxmox deployment
tooling.

The appliance deliberately separates three things:

```text
VM 9320              hardware-neutral Ubuntu 24.04 template
VM 320 root          disposable per-GPU software/driver instance
VM 320 model disk    durable model/data volume shared across rebuilds
```

The template contains no GPU, vendor driver, CUDA, ROCm, model disk, production
identity, or model data. A deployed clone selects one hardware profile and installs
only the stack appropriate to the GPU actually attached.

Current target profiles are:

- NVIDIA GeForce RTX 5070 Ti — Blackwell, CUDA 13.3, `sm_120`, open kernel modules.
- AMD Radeon RX 9070 XT — RDNA4, ROCm, `gfx1201`.
- NVIDIA Quadro P6000 — Pascal, CUDA 12.9, `sm_61`, proprietary R580 driver branch.

Ubuntu 24.04 is the common guest base for these profiles. GPU changes are normally
performed by rebuilding the small root disk from VM 9320 and reattaching the durable
160 GiB model/data virtual disk rather than converting an existing root filesystem
between vendor driver stacks. See `docs/gpu-swap.md`.

Katra storage remains isolated from its boot pool: the appliance uses the dedicated
`cuda-katra` LVM-thin store on the approved 256 GiB allocation of the Sandisk Optimus
5100. The host NVMe is not raw-passed into the guest.

The current reference target remains VM 320 with the RTX 5070 Ti. Acceptance for any
profile requires observed hardware identity, the intended GPU backend, a real compute
workload, and proof that CPU fallback did not silently substitute for the GPU.

Operator entry points are `bin/doctor`, `bin/probe`, `bin/run`,
`bin/validate-output`, and `bin/collect-evidence`. Host-side scripts under `proxmox/`
run only under an explicitly authorized host play.

Read `AGENTS.md`, `CODEX-HANDOFF.md`, `docs/appliance-contract.md`,
`docs/template-build.md`, and `docs/gpu-swap.md` before deployment work.
