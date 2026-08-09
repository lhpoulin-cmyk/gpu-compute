# Storage Policy

## Model storage hierarchy

```text
/mnt/models/
    library/    read-only during inference; Ollama and llama.cpp model store
    work/       active job working space; cleaned after successful promotion
    cache/      HuggingFace hub cache, pip cache, build artifacts
    output/     validated inference outputs; retained until explicit operator action
```

The directories live on a dedicated VM 320 virtual disk backed by Proxmox storage `cuda-katra`. They do **not** live on Katra's boot ZFS pool and the physical NVMe partition is not passed through to the guest. Always verify the guest mount with `findmnt -M /mnt/models` before reading or writing.

## Host storage provenance

Observed 2026-08-08:

- Host: `hv-katra`
- Physical device: `nvme0n1`
- Model string: `Sandisk Optimus 5100 1TB`
- Serial: `26100U800434`
- Stable by-id: `nvme-Sandisk_Optimus_5100_1TB_26100U800434`
- Observed state: unpartitioned, no filesystem

Authorized CUDA allocation:

- GPT partition 1: 256 GiB, LVM type
- VG: `cuda-katra-vg`
- Thin pool: `cuda-katra-thin`
- Proxmox storage ID: `cuda-katra`
- VM 9320 root disk: 32 GiB on `cuda-katra`
- VM 320 root disk: 64 GiB on `cuda-katra`
- VM 320 model disk: 160 GiB on `cuda-katra`
- Guest mount: `LABEL=cuda-models` → `/mnt/models`

The remaining physical SN5100 capacity stays unpartitioned and operator-reserved. `cuda-compute` may not consume it without separate authorization.

## Template policy

VM 9320 is temporary local construction/reference infrastructure. Retain it for 90 days after deployment/acceptance, then delete it only by explicit operator decision. The policy does not authorize automatic deletion.

## Ollama model management

Ollama models are stored under `/mnt/models/library` via `OLLAMA_MODELS`.

## Reserve enforcement

`bin/run` checks available space on `/mnt/models` before inference. If free space falls below 20 GiB or 20 percent (whichever is greater), the job is rejected.

## Root filesystem separation

Model weights, cache, and inference outputs must never be written to the root filesystem. If `/mnt/models` is unmounted, jobs fail closed. Template bootstrap is the only exception: template mode does not create model directories and therefore requires no model disk.
