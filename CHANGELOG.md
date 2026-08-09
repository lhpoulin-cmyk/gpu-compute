# Changelog

## 2026-08-08 Phase 4 accepted / guest stack implemented

- Accept VM 320 running as `cuda-compute-katra`, full-cloned from VM 9320 with all VM disks on `cuda-katra`, dual static NICs, and direct passthrough of `0000:01:00.0`.
- Remove the unnecessary Proxmox logical PCI mapping requirement for the fixed hv-katra reference host; retain exact PCI identity and `vfio-pci` preflight.
- Add guarded `bootstrap/prepare-model-disk.sh` for the blank 160 GiB model volume.
- Implement `bootstrap/stack-nvidia-modern.sh` for Ubuntu 26.04, NVIDIA branch 610 open modules, CUDA 13.3, verified Ollama 0.32.0, and pinned llama.cpp `b10173` / `sm_120`.
- Correct the unavailable `nvidia-open=610.57.04-1ubuntu1` profile pin to the current Ubuntu 26.04 repository version `610.43.02-1ubuntu1`; acceptance minimum remains `610.43.02`.
- Keep Ollama disabled/stopped until after the required reboot and successful NVIDIA smoke test to prevent accidental CPU fallback.
- Add `tests/unit/nvidia-modern-contract.sh` and fix workspace permissions for durable model work/output directories.

## 2026-08-08 Phase 4 deployment preparation

- Add concrete non-secret `proxmox/hv-katra-rtx5070ti.yaml` for VM 320.
- Replace placeholder/custom-snippet deployment with standard Proxmox cloud-init fields and a runtime SSH public-key file.
- Make `deploy-instance.sh` preflight the accepted template, storage reserve, bridges/MTU, exact RTX PCI identities, and host `vfio-pci` binding before mutation.
- Keep the 160 GiB model disk unformatted at host deployment time; formatting/mounting remains a separate first-boot gate.
- Retire `proxmox/example-profile.yaml` as non-executable historical example material.
- Add `tests/unit/deployment-contract.sh` to prevent reintroduction of placeholders, ISO fields, or custom cloud-init snippet dependencies.
- Preserve failure evidence by leaving a partially created VM in place rather than silently destroying it.

## 2026-08-08 Phase 3 accepted

- Accept VM 9320 as `tpl-compute-ubuntu2604-20260808`, an unbooted Ubuntu 26.04 cloud-image template on `cuda-katra`.
- Verify Canonical cloud-image release serial `20260612` with SHA-256 `0c9fb915bab0b36b361d3bf8aeae2115dda19d81a306656964de048033481670` before import.
- Record final template shape: 32 GiB `scsi0` plus EFI/cloud-init disks on `cuda-katra`, one `vmbr0` NIC, no GPU/model disk/vmbr1/local/local-zfs/raw-NVMe assignment.
- Record that the apparent `lvcreate` stall was only a disconnected execution session: Proxmox continued, completed disk import/resize/EFI/cloud-init configuration, and converted VM 9320 to a template at 23:21:53 without retry or repair.
- Record healthy post-build thin-pool state: Data% 0.86, Meta% 10.64, monitored, with no kernel I/O or NVMe errors observed.
- Advance the executable boundary to VM 320 deployment with the RTX 5070 Ti.

## 2026-08-08 Phase 3 construction simplification

- Replace the stale manual ISO/install/bootstrap/sanitize template flow with a direct, unbooted Canonical Ubuntu 26.04 cloud-image import to `cuda-katra`.
- Define concrete VM 9320 profile `tpl-compute-ubuntu2604-20260808`, 32 GiB root, q35/OVMF, `vmbr0` only, no GPU/model disk/vendor stack.
- Reuse the previously accepted Canonical release `20260612` image identity and require local SHA-256 verification before import.
- Move the RTX 5070 Ti modern profile to Ubuntu 26.04 / `ubuntu2604` while retaining CUDA 13.3 and the accepted high-value pins.
- Move the RX 9070 XT design profile to Ubuntu 26.04 / ROCm 7.14 / `gfx1201`.
- Mark the Quadro P6000 as legacy compatibility requiring a separate Ubuntu 24.04 disposable root/template when actually tested.
- Retire guest bootstrap and sanitation as VM 9320 construction requirements; GPU-specific software begins only on the deployed clone.
- Keep the abandoned Phase 3A transitive-package closure work as historical evidence rather than a deployment gate.

## 2026-08-08 Phase 3A construction checkpoint

- Record Phase 1 and Phase 2 as accepted; Phase 3 remains not started.
- Preserve the Phase 3A blocked finding: the isolated resolver authenticated the extracted Ubuntu archive keyring but also consulted live Ubuntu archives, so no deterministic CUDA closure was generated.
- Record that Debian `qemu-utils` is rejected because its proposed transaction removes the Proxmox stack; existing `pve-qemu-kvm` supplied `qemu-nbd` for the read-only verified-cloud-image keyring extraction.

## 2026-08-08 host execution authority doctrine correction

- Clarify that an explicit, bounded operator play on `hv-katra` authorizes the required host control-plane interfaces; a Codex sandbox limitation is an execution-environment limitation, not a project authority boundary.
- Preserve fail-closed scope controls and guest-runtime isolation while removing categorical wording that prohibited authorized host-side Proxmox, storage, and VFIO work.

## 2026-08-08 hv-katra Phase 1 storage provision

- Replace the stale ChatGPT-side evidence path with a verified local LifeTap 0.1.0 virtualization-baseline bundle (`2026-08-08T22:30:18Z`--`22:30:21Z`); create `config/active-hardware-profile.yaml` from observed host evidence and the frozen contract.
- Provision the approved first 256 GiB only of SN5100 `26100U800434` as GPT partition `cuda-katra-lvm`, PV `/dev/nvme0n1p1`, VG `cuda-katra-vg`, thin pool `cuda-katra-thin`, and active Proxmox LVM-thin storage `cuda-katra`.
- Verify 675.5 GiB remains unpartitioned, record pre/post CPU, PCH, and SN5100 telemetry, and retain checksummed Phase 1 evidence. No VFIO, VM, guest, CUDA, reboot, or network change was made.

## 2026-08-08 hv-katra evidence correction

- Treat current `vmbr1` state as operational: UP/LOWER_UP, `192.168.100.21/24`, MTU 9000; stale `enp2s0` journal text is non-blocking drift, not a down-bridge finding.
- Add dual-NIC VM 320 contract: `192.168.10.92/24` on `vmbr0` and `192.168.100.92/24` on `vmbr1` with MTU 9000.
- Correct RTX 5070 Ti identity to `10de:2c05` plus companion audio `10de:22e9`, compute capability 12.0, with both functions included in VFIO group handling.
- Pin Ubuntu 26.04 / CUDA 13.3 / `nvidia-open`, Ollama 0.32.0, and llama.cpp `b10173` built for `sm_120`.
- Preserve `BUILD` across the earlier booted-template design, make instance finalization write durable state, and strengthen GPU-only acceptance with compiled CUDA execution and inference processor proof.
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
