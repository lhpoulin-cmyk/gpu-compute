# Current state

## 2026-08-08 accepted host / VM state

The following phases are complete and accepted:

- Phase 1 storage: **ACCEPTED**
- Phase 2 VFIO/reboot validation: **ACCEPTED**
- Phase 3 Ubuntu 26.04 template construction: **ACCEPTED**
- Phase 4 VM 320 construction/start: **ACCEPTED**

`cuda-katra` remains the dedicated LVM-thin store on the approved first 256 GiB of
the Sandisk Optimus 5100. The remaining ~675.5 GiB remains unpartitioned. Both host
bridges remain healthy and `vmbr1` remains MTU 9000.

## Accepted template VM 9320

VM 9320 is `tpl-compute-ubuntu2604-20260808`, an unbooted-before-conversion Ubuntu
26.04 Canonical cloud-image template. Its 32 GiB root, EFI disk, and cloud-init disk
are all on `cuda-katra`. It has one `vmbr0` NIC and no GPU, model disk, `vmbr1`,
local/local-zfs VM disk, or raw NVMe assignment.

The accepted source image is Canonical release serial `20260612`, SHA-256
`0c9fb915bab0b36b361d3bf8aeae2115dda19d81a306656964de048033481670`.

## Accepted reference VM construction

VM 320 now exists and is running as `cuda-compute-katra`:

- full clone of VM 9320;
- 8 vCPU / 16384 MiB RAM;
- 32 GiB root, EFI, cloud-init, and 160 GiB `scsi1` all on `cuda-katra`;
- no VM disk on `local` or `local-zfs`;
- `vmbr0`: `192.168.10.92/24`, gateway `192.168.10.1`;
- `vmbr1`: `192.168.100.92/24`, MTU 9000, no gateway;
- DNS `192.168.10.250 192.168.10.251`, search domain `home.arpa`;
- direct PCI passthrough of host function `0000:01:00.0` as `hostpci0`;
- host compute function identity `10de:2c05` and companion audio `10de:22e9` were
  verified under `vfio-pci` before deployment.

A Proxmox logical PCI mapping is intentionally **not** required for this fixed
single-host reference implementation. Direct BDF passthrough is guarded by exact PCI
identity and host-driver preflight.

## Guest construction implementation

The current branch now contains the previously missing executable RTX 5070 Ti guest
stack:

- `bootstrap/prepare-model-disk.sh` — identifies exactly one unambiguous ~160 GiB
  non-root blank disk, refuses existing signatures/partitions/mounts, formats ext4
  `LABEL=cuda-models`, and mounts `/mnt/models`;
- `bootstrap/stack-nvidia-modern.sh` — Ubuntu 26.04 NVIDIA network-repository setup,
  bounded APT simulation, branch-610 open driver, CUDA 13.3, verified Ollama 0.32.0,
  and pinned llama.cpp `b10173` build for `sm_120`;
- `bootstrap/packages.sh` — dispatches the modern NVIDIA stack and keeps AMD/Pascal
  non-executable on this instance;
- `bootstrap/install-profile.sh` — installs instance profile/kernel/service state
  without duplicating driver package installation;
- `bootstrap/install.sh` — completes installation but explicitly defers GPU acceptance
  until after reboot;
- `tests/unit/nvidia-modern-contract.sh` — regression contract for the guest stack.

The NVIDIA Ubuntu 26.04 repository currently exposes branch-610 `nvidia-open`
`610.43.02-1ubuntu1`, so the profile uses that available version and keeps acceptance
minimum `610.43.02`. CUDA toolkit remains `cuda-toolkit-13-3=13.3.1-1`.

## Next executable boundary — finish VM 320 guest construction

No CUDA/NVIDIA guest packages have yet been installed and the 160 GiB model disk is
still unformatted.

The next play should:

1. verify first-boot Ubuntu 26.04, both static addresses, SSH access, and raw RTX PCI
   visibility inside VM 320;
2. record Secure Boot state before DKMS installation;
3. run `bootstrap/prepare-model-disk.sh --dry-run`, review the one detected ~160 GiB
   disk, then apply it;
4. transfer the current repository snapshot from hv-katra into `/srv/cuda-compute`
   without GitHub credentials;
5. run the RTX profile bootstrap dry-run;
6. apply the bounded NVIDIA/CUDA/Ollama/llama.cpp installation;
7. reboot VM 320;
8. run smoke and hardware acceptance after the reboot;
9. finalize instance state only after acceptance passes.

The earlier full transitive-package closure experiment remains historical evidence and
is not a deployment prerequisite.

## Other GPU families

- RX 9070 XT: Ubuntu 26.04 / ROCm 7.14 / `gfx1201`; design-stage until local testing.
- future Arc Pro B70: may use the Ubuntu 26.04 modern template when a B70 is local.
- Quadro P6000: legacy Ubuntu 24.04 disposable root/template only when actually tested.
