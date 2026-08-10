# Reference Implementation

VM 320 (`cuda-compute-katra`) is the reference implementation for this
appliance on `hv-katra`. It proves the appliance contract against the RTX 5070
Ti and the SN5100 NVMe storage partition.

## What VM 320 is

- A running, accepted production instance of this appliance.
- The regression target for future profile and stack changes.
- The source of observed hardware evidence recorded in `CURRENT_STATE.md`.

## What VM 320 is not

- A clone source. VM 9320 is the clean template; VM 320 accumulates runtime
  history, model weights, and job evidence that must not propagate to clones.
- An authoritative model repository. Models pulled to `/mnt/models/library`
  are operational artifacts, not canonical releases.
- A multi-tenant inference server. The Ollama API is loopback-only.

## Relationship to the template

```text
VM 9320 (tpl-cuda-compute-ubuntu2604-*):
  - Ubuntu 26.04 LTS base install
  - No GPU, no NVMe passthrough, no identity
  - Appliance workspace /srv/gpu-compute present
  - Packages installed but NVIDIA driver not activated
  - cloud-init ready; sanitized of all instance identity

VM 320 (cuda-compute-katra):
  - Clone of VM 9320 at deployment time
  - RTX 5070 Ti attached via resource mapping gpu-compute-rtx5070ti
  - root disk and model scsi1 both backed by dedicated Proxmox LVM-thin storage `cuda-katra`; model disk mounted at /mnt/models by filesystem label
  - NVIDIA driver installed and activated
  - Ollama running with CUDA backend
  - Accepted against hardware and representative model
```

## Evidence captured from VM 320

All evidence from the reference implementation is stored under
`evidence/` (gitignored) on the guest and referenced in `CURRENT_STATE.md`
in this repository. Do not commit raw evidence, logs, model weights, or
runtime state to this repository.
