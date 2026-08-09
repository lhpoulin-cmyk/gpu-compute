# Changelog

## 2026-08-08 Phase 3A construction checkpoint

- Record Phase 1 and Phase 2 as accepted; Phase 3 remains not started.
- Preserve the Phase 3A blocked finding: the isolated resolver authenticated the extracted Ubuntu archive keyring but also consulted live Ubuntu archives, so no deterministic CUDA closure was generated.
- Record that Debian `qemu-utils` is rejected because its proposed transaction removes the Proxmox stack; existing `pve-qemu-kvm` supplied `qemu-nbd` for the read-only verified-cloud-image keyring extraction.

## 2026-08-08 host execution authority doctrine correction

- Clarify that an explicit, bounded operator play on `hv-katra` authorizes the
  required host control-plane interfaces; a Codex sandbox limitation is an
  execution-environment limitation, not a project authority boundary.
- Preserve fail-closed scope controls and guest-runtime isolation while
  removing categorical wording that prohibited authorized host-side Proxmox,
  storage, and VFIO work.

## 2026-08-08 hv-katra Phase 1 storage provision

- Replace the stale ChatGPT-side evidence path with a verified local LifeTap 0.1.0 virtualization-baseline bundle (`2026-08-08T22:30:18Z`--`22:30:21Z`); create `config/active-hardware-profile.yaml` from observed host evidence and the frozen contract.
- Provision the approved first 256 GiB only of SN5100 `26100U800434` as GPT partition `cuda-katra-lvm`, PV `/dev/nvme0n1p1`, VG `cuda-katra-vg`, thin pool `cuda-katra-thin`, and active Proxmox LVM-thin storage `cuda-katra`.
- Verify 675.5 GiB remains unpartitioned, record pre/post CPU, PCH, and SN5100 telemetry, and retain checksummed Phase 1 evidence. No VFIO, VM, guest, CUDA, reboot, or network change was made.

## 2026-08-08 hv-katra evidence correction

- Treat current `vmbr1` state as operational: UP/LOWER_UP, `192.168.100.21/24`, MTU 9000; stale `enp2s0` journal text is non-blocking drift, not a down-bridge finding.
- Add dual-NIC VM 320 contract: `192.168.10.92/24` on `vmbr0` and `192.168.100.92/24` on `vmbr1` with MTU 9000.
- Correct RTX 5070 Ti identity to `10de:2c05` plus companion audio `10de:22e9`, compute capability 12.0, with both functions included in VFIO group handling.
- Pin Ubuntu 26.04 / CUDA 13.3 / `nvidia-open`, Ollama 0.32.0, and llama.cpp `b10173` built for `sm_120`.
- Preserve `BUILD` across template sanitation, make instance finalization write durable state, and strengthen GPU-only acceptance with compiled CUDA execution and inference processor proof.
- Replace unreliable inference of the llama.cpp source tag from binary version output with a durable installed-ref marker.


## development (unreleased)

- Reworked hv-katra storage: 256 GiB SN5100 allocation becomes dedicated Proxmox LVM-thin storage `cuda-katra`; VM 9320 and VM 320 root disks plus VM 320 model disk live there. Raw NVMe passthrough removed. VM 9320 retention set to 90 days.

- Initial repository structure modeled after Helix-ARPA GPU encode appliance.
- NVIDIA RTX 5070 Ti hardware profile for hv-katra deployment.
- Proxmox tooling for VM 320 creation from template VM 9320.
- Dedicated LVM-thin provisioning runbook for the SN5100 256 GiB allocation.
- Ollama and llama.cpp production inference stack.
- CUDA 13.3 and Vulkan validation paths.
- Operator entry points: doctor, probe, run, validate-output, collect-evidence.
- Smoke and acceptance test scaffolding.
