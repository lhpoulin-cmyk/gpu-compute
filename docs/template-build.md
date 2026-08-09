# Template Build — VM 9320

VM 9320 is a temporary, hardware-neutral construction template for the CUDA/ROCm
compute appliance family. It lives on `cuda-katra`, not the host boot pool, and is
retained for 90 days unless the operator explicitly removes it sooner or extends
retention.

## Why Ubuntu 24.04

The template uses Ubuntu 24.04 LTS as the common denominator for the current swap
profiles. CUDA 13.3 supports Ubuntu 24.04 for Blackwell; CUDA 12.9 supports Ubuntu
24.04 and is the final CUDA major series capable of targeting Pascal; current ROCm
supports the RX 9070 XT (`gfx1201`) on Ubuntu 24.04. The template therefore does not
need to change when the physical GPU changes.

## Shape

- VMID: 9320
- Name: `tpl-compute-ubuntu2404-20260808`
- OS: Ubuntu Server 24.04 LTS
- Root disk: 32 GiB on `cuda-katra`
- Network during construction: `vmbr0` only
- No GPU attached
- No model disk attached
- No NVIDIA or AMD GPU driver
- No CUDA or ROCm toolkit
- No Ollama or llama.cpp build
- No production instance identity or model data

## Build

Use the concrete host profile in `proxmox/hv-katra-template.yaml` and the reviewed
host tooling. Dry-run first, then apply only after the rendered VM shape matches the
contract.

Inside VM 9320, use the generic template profile:

```bash
bootstrap/install.sh \
  --profile config/profiles/generic/profile.yaml \
  --template-mode --dry-run
bootstrap/install.sh \
  --profile config/profiles/generic/profile.yaml \
  --template-mode --apply
```

Template mode installs only common guest/build prerequisites and the appliance
workspace. GPU-vendor software is deliberately deferred until a real clone has a
real GPU profile.

## Sanitize

Inside VM 9320:

```bash
proxmox/sanitize-template.sh
shutdown -h now
```

`sanitize-template.sh` removes machine identity, SSH host keys, cloud-init instance
state, runtime evidence, and active hardware/instance state. It preserves `BUILD`,
because `BUILD` is appliance software identity.

On `hv-katra`:

```bash
qm template 9320
```

Do not attach any GPU or the model disk to VM 9320.

## After template conversion

GPU-specific software is installed only on the clone using one of the hardware
profiles. See `docs/gpu-swap.md`. This keeps the root disk disposable and lets the
same template serve the RTX 5070 Ti, RX 9070 XT, and Quadro P6000 without carrying
conflicting vendor stacks.
