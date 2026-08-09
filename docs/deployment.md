# Deployment

## Accepted infrastructure state

The hv-katra reference path begins from accepted Phase 1--4 state:

- dedicated `cuda-katra` LVM-thin storage on the approved 256 GiB SN5100 allocation;
- accepted Ubuntu 26.04 template VM 9320;
- VM 320 running as `cuda-compute-katra`;
- direct passthrough of RTX 5070 Ti compute function `0000:01:00.0`;
- healthy `vmbr0` and `vmbr1`, with `vmbr1` MTU 9000;
- all VM 320 disks on `cuda-katra`.

The fixed single-host reference implementation does not require a Proxmox logical PCI
mapping. The deployment script validates the exact compute/audio PCI IDs and
`vfio-pci` ownership before direct `hostpci0` attachment.

## VM 320 contract

- VMID 320 / `cuda-compute-katra`;
- 8 vCPU / 16384 MiB RAM;
- root 64 GiB on `cuda-katra` (full clone of the 32 GiB VM 9320 template,
  expanded before first boot);
- model disk 160 GiB on `cuda-katra`;
- `192.168.10.92/24` on `vmbr0`, gateway `192.168.10.1`;
- `192.168.100.92/24` on `vmbr1`, MTU 9000, no gateway;
- DNS `192.168.10.250 192.168.10.251`;
- search domain `home.arpa`;
- direct RTX compute passthrough `0000:01:00.0`.

## First-boot guest construction

The model disk is intentionally created blank by the host deployment. Inside VM 320,
run the guarded preparation script first:

```bash
sudo /srv/cuda-compute/bootstrap/prepare-model-disk.sh --dry-run
sudo /srv/cuda-compute/bootstrap/prepare-model-disk.sh --apply
```

The script requires exactly one unambiguous ~160 GiB non-root blank disk and refuses
existing partitions, signatures, or mounts. It creates ext4 `LABEL=cuda-models`, adds
the `/mnt/models` fstab entry, and mounts it.

Transfer the current source snapshot from the host checkout into `/srv/cuda-compute`.
Do not place GitHub credentials or private SSH keys in the guest.

Then run the RTX 5070 Ti bootstrap:

```bash
sudo /srv/cuda-compute/bootstrap/install.sh \
  --profile /srv/cuda-compute/config/profiles/nvidia-rtx5070ti/profile.yaml \
  --operator louis --dry-run

sudo /srv/cuda-compute/bootstrap/install.sh \
  --profile /srv/cuda-compute/config/profiles/nvidia-rtx5070ti/profile.yaml \
  --operator louis
```

The apply path uses the official NVIDIA Ubuntu 26.04 network repository/keyring,
simulates the focused package transaction and refuses removals, installs the pinned
branch-610 open driver and CUDA 13.3 toolkit meta packages, verifies and installs the
pinned Ollama asset, and builds the exact llama.cpp commit for `sm_120`.

Ollama remains disabled and stopped through this stage. Reboot before hardware tests.

## Post-reboot acceptance

After SSH returns:

```bash
cd /srv/cuda-compute
tests/smoke/cuda-nvidia
```

Only when that passes, enable the inference service:

```bash
sudo systemctl enable --now ollama.service
```

Then run:

```bash
tests/smoke/appliance
tests/acceptance/appliance
```

Acceptance must prove the RTX 5070 Ti identity, compute capability 12.0, driver >=
610.43.02, CUDA toolkit 13.3, compiled CUDA kernel execution, llama.cpp CUDA device,
model storage, repeated GPU-backed Ollama inference, and output hashes.

Finalize instance state only after acceptance passes.

## Secure Boot / DKMS

Record `mokutil --sb-state` before driver installation when available. Secure Boot is
not itself a reason to abandon the build. If the NVIDIA module does not load after
reboot, capture DKMS/module/Secure Boot evidence and resolve that specific signing
condition before enabling Ollama. Do not accept CPU fallback.
