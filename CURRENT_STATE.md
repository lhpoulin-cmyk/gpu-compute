# Current state

## 2026-08-08 evidence-backed definition

The verified local LifeTap Phase 1 refresh (`evidence/20260808-phase1-lifetap-hv-katra`, captured 2026-08-08T22:30:18Z--22:30:21Z) is the installation baseline for `hv-katra`. Its checked manifest digest is recorded under `docs/evidence/`.

Observed host state relevant to this appliance:

- Proxmox VE `9.2.2`, kernel `7.0.14-6-pve`.
- Intel Core i7-9700KF, 8 cores / 8 CPUs, ~31.3 GiB RAM.
- `vmbr0` is UP at `192.168.10.21/24`, MTU 1500.
- `vmbr1` is **UP, LOWER_UP**, operational state UP, at
  `192.168.100.21/24`, MTU 9000. Guest interfaces are forwarding on it.
  A stale `enp2s0` boot-journal error is not treated as evidence that the
  bridge is down.
- RTX 5070 Ti compute function: `0000:01:00.0`, PCI ID `10de:2c05`.
- RTX 5070 Ti audio function: `0000:01:00.1`, PCI ID `10de:22e9`.
- Both GPU functions are in IOMMU group 1.
- Sandisk Optimus 5100 1TB: `nvme0n1`, serial `26100U800434`, stable by-id
  `nvme-Sandisk_Optimus_5100_1TB_26100U800434`, now has only GPT partition 1: exactly 256 GiB, type `8E00`, label `cuda-katra-lvm`. The remaining 675.5 GiB is unpartitioned.

Phase 1 is **ACCEPTED**: `/dev/nvme0n1p1` is the PV in `cuda-katra-vg`; its active `cuda-katra-thin` pool is registered as Proxmox storage `cuda-katra`. Phase 2 is **ACCEPTED**: post-reboot VFIO binding is retained for both GPU functions and the host-owned root port remains `pcieport`.

Phase 3 has **NOT STARTED**: no VM 9320, VM disk, guest, or template exists. Phase 3A is **BLOCKED** pending a corrected snapshot-only isolated Ubuntu resolver/build-contract implementation. The current resolver demonstrated that its configuration consulted live Ubuntu archive endpoints as well as the accepted snapshot; no closure lock or deterministic software lock may be claimed from that transaction.

## Locked deployment design

- Guest OS: Ubuntu Server 26.04 LTS.
- CUDA toolkit: **13.3**, pinned to package branch `cuda-toolkit-13-3`.
- NVIDIA guest driver: open kernel modules via `nvidia-open`; acceptance
  requires driver `610.43.02` or later.
- GPU: GeForce RTX 5070 Ti, compute capability **12.0**, 16 GiB VRAM.
- Ollama: pinned `0.32.0`, loopback API, models under `/mnt/models/library`.
- llama.cpp: pinned tag `b10173`, built with `GGML_CUDA=ON` and
  `CMAKE_CUDA_ARCHITECTURES=120`.
- CPU fallback: rejected for production jobs.
- VM 320: 8 vCPU, 16 GiB RAM.
- VM 320 network: `192.168.10.92/24` on `vmbr0`; `192.168.100.92/24` on
  `vmbr1`, MTU 9000. Default route only through `192.168.10.1`.
- Dedicated host allocation: first 256 GiB of the blank SN5100 becomes
  Proxmox LVM-thin storage `cuda-katra`; remaining physical capacity stays
  untouched.
- VM 9320 root: 32 GiB on `cuda-katra`, temporary retention 90 days.
- VM 320 root: 32 GiB on `cuda-katra`.
- VM 320 model/data disk: 160 GiB on `cuda-katra`, ext4 label `cuda-models`,
  mounted at `/mnt/models`.
- No VM disk is placed on Katra's existing boot pool.

## Acceptance still pending

Acceptance is intentionally not claimed until VM 320 exists and proves:

- exact RTX 5070 Ti identity and compute capability 12.0;
- driver >= 610.43.02 and CUDA toolkit exactly 13.3;
- compiled CUDA kernel execution on the passed-through GPU;
- llama.cpp exposes the RTX 5070 Ti as `CUDA0`;
- repeated Ollama inference with `ollama ps` proving GPU residency;
- mounted model storage and reserve policy;
- output validation and machine-readable acceptance evidence.
