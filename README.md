# Helix-ARPA gpu-compute Appliance

This repository is the source of truth for a reusable GPU compute appliance on
`hv-katra`. It contains policy, bootstrap logic, hardware profiles, operator commands,
validation tests, evidence references, and reviewed Proxmox deployment tooling.

`cuda-compute` was the original NVIDIA/CUDA implementation that established
the first accepted gpu-compute appliance. Historical CUDA names remain valid
provenance; the active appliance authority is now vendor-agnostic gpu-compute.

The appliance separates operating-system roots from durable workload data:

```text
VM 9320              accepted hardware-neutral Ubuntu 26.04 modern template
VM 320 root          disposable per-GPU software/driver instance
VM 320 model disk    durable model/data volume preserved across rebuilds
```

VM 9320 is an accepted Canonical cloud-image template. VM 320 is now running as the
RTX 5070 Ti reference candidate with all virtual disks on `cuda-katra`, dual static
NICs, and direct passthrough of host PCI function `0000:01:00.0`.

Modern target profiles are:

- NVIDIA GeForce RTX 5070 Ti — Ubuntu 26.04, CUDA 13.3, `sm_120`, open kernel modules.
- AMD Radeon RX 9070 XT — Ubuntu 26.04, ROCm 7.14, `gfx1201` (design-stage until locally tested).
- Future Intel Arc Pro B70 work may reuse the Ubuntu 26.04 template when a B70 is local.

Legacy compatibility is separate:

- NVIDIA Quadro P6000 — Pascal, CUDA 12.9, `sm_61`, proprietary R580 branch, separate Ubuntu 24.04 root/template when tested.

The current RTX 5070 Ti guest path is implemented in `bootstrap/`: guarded model-disk
preparation, official NVIDIA Ubuntu repository setup, bounded APT simulation,
`nvidia-open`, CUDA 13.3, verified Ollama 0.32.0 installation, and pinned llama.cpp
`b10173` build for `sm_120`. Ollama stays disabled until the post-reboot GPU smoke test
passes so CPU fallback cannot silently become the service path.

Katra storage remains isolated from its boot pool: the appliance uses the dedicated
`cuda-katra` LVM-thin store on the approved 256 GiB allocation of the Sandisk Optimus
5100. The host NVMe is not raw-passed into the guest.

The durable compute interface is `/mnt/models` with filesystem label
`cuda-models`. Its contract is independent of the Proxmox backing store:
`cuda-katra` is the accepted LVM-thin implementation today, while a later ZFS
or Ceph RBD transition is storage migration work—not application redesign.

The abandoned full transitive-package closure experiment is historical evidence, not
a deployment gate. Use trusted vendor sources, bounded transaction simulation,
high-value pins, exact installed-version recording, and live hardware acceptance.

Read `AGENTS.md`, `CODEX-HANDOFF.md`, `CURRENT_STATE.md`, `docs/deployment.md`, and
`docs/gpu-swap.md` before deployment work.
