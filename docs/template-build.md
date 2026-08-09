# Template Build — VM 9320

VM 9320 is a temporary, generic construction template for VM 320. It lives on
`cuda-katra`, not the host boot pool, and is retained for 90 days unless the
operator explicitly removes it sooner or extends retention.

## Shape

- VMID: 9320
- Name: `tpl-cuda-compute-ubuntu2604-20260808`
- OS: Ubuntu Server 26.04 LTS minimal
- Root disk: 32 GiB on `cuda-katra`
- Network during construction: `vmbr0` only
- No GPU attached
- No model disk attached
- No instance identity or model data

## Build

On `hv-katra`:

```bash
proxmox/create-template.sh --profile PRIVATE_PROFILE.yaml --dry-run
proxmox/create-template.sh --profile PRIVATE_PROFILE.yaml --apply
```

Install Ubuntu 26.04, clone this repository to `/srv/cuda-compute`, then run:

```bash
bootstrap/install.sh \
  --profile config/profiles/nvidia-rtx5070ti/profile.yaml \
  --template-mode --dry-run
bootstrap/install.sh \
  --profile config/profiles/nvidia-rtx5070ti/profile.yaml \
  --template-mode --apply
```

Template mode installs the pinned CUDA 13.3 toolkit, pinned Ollama release, and
pinned CUDA-enabled llama.cpp build. It deliberately does not require
`/mnt/models`, does not activate the NVIDIA guest driver, and leaves Ollama
disabled.

## Sanitize

Inside VM 9320:

```bash
proxmox/sanitize-template.sh
shutdown -h now
```

`sanitize-template.sh` removes machine identity, SSH host keys, cloud-init
instance state, runtime evidence, and active hardware/instance state. It
**preserves `BUILD`**, because `BUILD` is appliance software identity and is a
required smoke-test input.

On `hv-katra`:

```bash
qm template 9320
```

Do not attach the RTX 5070 Ti or model disk to VM 9320.
