# Helix-ARPA CUDA Compute Appliance

This repository is the source of truth for a reusable, dedicated NVIDIA GPU
compute appliance. It contains policy, bootstrap logic, hardware profiles,
operator commands, cloud-init examples, validation tests, evidence references,
and reviewed Proxmox deployment tooling.

The appliance has three deliberately separate layers:

```text
VM 320                 working hv-katra CUDA compute reference implementation
this Git repository    authoritative reusable appliance source
VM 9320                temporary clean generic Ubuntu template (90-day retention)
```

VM 320 proves the contract and remains a normal production VM. It is never the
clone source. VM 9320 contains no GPU, raw disk, instance identity, credentials,
or model data. A private deployment profile assigns the real host, GPU resource
mapping, Proxmox storage, network, and identity to a clone. Acceptance tests then
promote that clone into an appliance.

The hv-katra reference profile is pinned to Ubuntu 26.04, NVIDIA open kernel
modules, CUDA toolkit 13.3, RTX 5070 Ti compute capability 12.0, Ollama 0.32.0,
and llama.cpp ref `b10173` built for `sm_120`. Production GPU use is explicit
through `/dev/nvidia0`; CPU fallback is rejected unless a future profile
explicitly authorizes it. Vulkan is validated as an auxiliary compute path.

Katra storage is intentionally isolated from its boot pool: the appliance uses
the dedicated `cuda-katra` LVM-thin store on the approved 256 GiB allocation of
the Sandisk Optimus 5100. VM 320 receives separate root and model/data virtual
disks from that store; the host NVMe is not raw-passed into the guest.

Operator entry points are `bin/doctor`, `bin/probe`, `bin/run`,
`bin/validate-output`, and `bin/collect-evidence`. Bootstrap begins with
`bootstrap/install.sh --dry-run --profile config/profiles/nvidia-rtx5070ti/profile.yaml`.
Host-side scripts under `proxmox/` render or perform only explicitly authorized
Proxmox operations; they must not be executed from VM 320.

Read `AGENTS.md`, `CODEX-HANDOFF.md`, `docs/appliance-contract.md`, and
`docs/reference-implementation.md` before changing a deployed instance.
