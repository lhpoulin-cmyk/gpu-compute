# Helix-ARPA GPU Compute Appliance

This repository is the source of truth for a reusable GPU compute appliance on
`hv-katra`. It contains policy, bootstrap logic, hardware profiles, operator
commands, validation tests, evidence references, and reviewed Proxmox deployment
tooling.

The appliance deliberately separates operating-system roots from durable workload
data:

```text
VM 9320              hardware-neutral Ubuntu 26.04 modern template
VM 320 root          disposable per-GPU software/driver instance
VM 320 model disk    durable model/data volume preserved across rebuilds
```

VM 9320 is an **unbooted Canonical cloud-image template**. It contains no GPU,
vendor driver, CUDA, ROCm, cuda-compute checkout, model disk, production identity,
or model data. A deployed clone selects one hardware profile and installs only the
stack appropriate to the GPU actually attached.

Modern target profiles are:

- NVIDIA GeForce RTX 5070 Ti — Ubuntu 26.04, Blackwell, CUDA 13.3, `sm_120`, open kernel modules.
- AMD Radeon RX 9070 XT — Ubuntu 26.04, RDNA4, ROCm 7.14, `gfx1201` (design-stage until locally tested).
- Future Intel Arc Pro B70 work may join the Ubuntu 26.04 modern template when a B70 is local to the test platform.

Legacy compatibility is separate:

- NVIDIA Quadro P6000 — Pascal, CUDA 12.9, `sm_61`, proprietary R580 branch, separate Ubuntu 24.04 root/template when tested.

GPU changes normally use a fresh disposable root plus the same durable 160 GiB
model/data virtual disk rather than converting an existing root filesystem between
vendor stacks. See `docs/gpu-swap.md`.

Katra storage remains isolated from its boot pool: the appliance uses the dedicated
`cuda-katra` LVM-thin store on the approved 256 GiB allocation of the Sandisk Optimus
5100. The host NVMe is not raw-passed into the guest.

The immediate reference target remains VM 320 with the RTX 5070 Ti. Acceptance for
any profile requires observed hardware identity, the intended GPU backend, a real
compute workload, and proof that CPU fallback did not silently substitute for the
GPU.

Operator entry points are `bin/doctor`, `bin/probe`, `bin/run`,
`bin/validate-output`, and `bin/collect-evidence`. Host-side scripts under
`proxmox/` run only under an explicitly authorized host play.

Read `AGENTS.md`, `CODEX-HANDOFF.md`, `docs/appliance-contract.md`,
`docs/template-build.md`, and `docs/gpu-swap.md` before deployment work.
