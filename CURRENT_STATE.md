# Current state

## Accepted host / VM state

Accepted:

- Phase 1 storage
- Phase 2 VFIO/reboot validation
- Phase 3 Ubuntu 26.04 template construction
- Phase 4 VM 320 construction/start
- VM 320 guest-network recovery
- encrypted SOPS/age preservation of network-recovery evidence
- 160 GiB model-disk preparation

VM 9320 remains the accepted Ubuntu 26.04 template on `cuda-katra`.

VM 320 is running as `cuda-compute-katra` with:

- 8 vCPU / 16384 MiB RAM
- root/EFI/cloud-init/model disks on `cuda-katra`
- direct RTX 5070 Ti passthrough (`10de:2c05`)
- `ens18`: `192.168.10.92/24`, default route via `192.168.10.1`
- `ens19`: `192.168.100.92/24`, MTU 9000, no gateway
- DNS `192.168.10.250 192.168.10.251`, search `home.arpa`
- `/dev/sdb`: ext4, `LABEL=cuda-models`, mounted `/mnt/models`
- Secure Boot enabled

The cloud-init network fault was a failed attempted rename of the primary NIC to
`eth0`; recovery replaced the guest netplan with MAC-bound definitions and disabled
cloud-init network rewrites. Host networking, VFIO, GPU attachment, and storage layout
were untouched.

Recovery evidence is sealed in Git under `evidence/encrypted/` using SOPS + age and
passed decrypt/SHA-256 round-trip verification.

## Current RTX software contract

Driver policy is now deliberately branch-based rather than point-release pinned:

- package: `nvidia-open`
- branch: `610`
- policy: newest authenticated version in branch 610
- minimum driver: `610.43.02`
- exact CUDA toolkit: `cuda-toolkit-13-3=13.3.1-1`

Live authenticated repository evidence on 2026-08-09 showed
`nvidia-open=610.57.04-1ubuntu1`. The earlier exact `610.43.02-1ubuntu1` pin caused the
installer to fail closed before any NVIDIA/CUDA mutation. The installer now chooses
the newest eligible branch-610 package, records the selected version, and still
refuses package removals or a CUDA candidate change.

Application/toolchain pins remain:

- Ollama `0.32.0`
- llama.cpp `b10173`
- llama.cpp commit `e9fa0781f1c25fc4fe8c86be1edc6970661ad6f0`
- CUDA architecture `sm_120`

No NVIDIA driver, CUDA toolkit, Ollama, or llama.cpp installation has yet occurred.

## Next executable boundary

Resume directly from the prepared VM 320:

1. sync the updated branch and transfer the refreshed source snapshot to the guest;
2. run regression/syntax checks;
3. run the RTX installer dry-run;
4. apply, selecting the newest authenticated branch-610 driver and exact CUDA 13.3
   toolkit;
5. reboot;
6. prove NVIDIA/CUDA hardware execution;
7. enable Ollama only after GPU smoke passes;
8. run appliance/inference acceptance;
9. finalize instance state only after acceptance passes.

Do not redo networking, evidence sealing, model-disk formatting, VM construction, or
host passthrough setup.
