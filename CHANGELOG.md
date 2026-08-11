# Changelog

## 2026-08-11 Qwen2.5-Coder 32B runtime profile

- Register the exact Qwen2.5-Coder 32B Q4_K_M artifact's measured Katra
  profile at context 4096: 71% GPU / 29% CPU and 14,634 MiB peak VRAM.
- Preserve the one-pull, three-probe no-retry runtime evidence under the
  canonical guest evidence root. Runtime acceptance does not grant V2
  production admission.

## 2026-08-11 Qwen2.5-Coder 14B runtime profile

- Register the exact Qwen2.5-Coder 14B Q4_K_M artifact's measured Katra
  profile at context 4096: 100% GPU / 0% CPU and 9,304 MiB peak VRAM.
- Preserve the three no-retry neutral probe records under the canonical guest
  evidence root and add exact-profile stale-digest coverage. Runtime acceptance
  does not grant V2 production admission.

## 2026-08-11 Ollama repeat-limit terminalization

- Carry a minimal local patch against exact upstream Ollama v0.32.0 commit
  `f1a0ffd6219b5ef82aee77254f895b383efb5486` so the unchanged repeated-token
  guard emits a terminal `repeat_limit` outcome instead of returning a nil
  context error and closing HTTP 200 nonterminally.
- Add a reproducible server-only Go build recipe, exact patch/toolchain/binary
  provenance, model-free Completion and streaming/non-streaming route tests,
  normal-stop and cancellation regressions, and an upstream-ready issue packet.
- Classify the terminal model outcome as `MODEL_REPEAT_LIMIT`, retaining its
  prior content as evaluator-only partial evidence rather than a successful
  coding response.

## 2026-08-11 Ollama nonterminal HTTP forensics

- Add a Devstral-bounded, evaluator-only HTTP capture that records exact
  non-stream and streaming response bodies, headers, ordered events, request
  field presence, and runtime-profile evidence without changing the production
  machine-response transport.

## 2026-08-11 Ollama failure-envelope evidence

- Advance evaluator-only evidence retention to `OLLAMA_RESPONSE_META_V2`,
  recording field presence separately from value before terminality checks.
- Retain nonterminal response bytes as hash-bound `partial-response.txt`, never
  as successful `response.txt`, and distinguish explicit `done=false`, missing
  `done`, and invalid-envelope failure states in `bin/run-status`.
- Keep `OLLAMA_MACHINE_RESPONSE_V1` generation transport and successful
  response bytes unchanged.

## 2026-08-11 Ollama completion evidence

- Retain a hash-bound `OLLAMA_RESPONSE_META_V1` sidecar for successful
  controlled invocations, preserving Ollama terminal reason, token counts, and
  durations without changing the exact response bytes or model-visible
  transport.
- Fail closed on nonterminal or malformed Ollama envelopes and expose bounded
  sidecar availability through `bin/run-status`.

## 2026-08-11 Devstral runtime profile

- Register the gpu-cp accepted exact Devstral Small 2 24B Q4 profile at the
  observed 88% GPU / 12% CPU envelope and add fail-closed boundary tests.

## 2026-08-10 idempotent controlled inference

- Add durable caller invocation identities, retained invocation responses, and
  a bounded status interface so client interruption cannot cause duplicate
  model execution.

## 2026-08-09 RTX 5070 Ti reference appliance accepted

- Grow VM 320 `scsi0` from the 32 GiB neutral-template clone to its 64 GiB
  deployed-instance contract before acceptance; VM 9320 remains unchanged at
  32 GiB.
- Make the llama.cpp CMake build and compiled CUDA smoke invoke the pinned
  `/usr/local/cuda-13.3/bin/nvcc` directly, avoiding the `/usr/local/bin/nvcc`
  symlink's incorrect toolkit-root discovery.
- Install `nvidia-open=610.57.04-1ubuntu1` and
  `cuda-toolkit-13-3=13.3.1-1`; enroll the local DKMS MOK under Secure Boot.
- Build pinned llama.cpp `b10173` at commit
  `e9fa0781f1c25fc4fe8c86be1edc6970661ad6f0` for `sm_120`, and install
  Ollama `0.32.0`.
- Pass CUDA smoke including a compiled compute-capability-12.0 kernel, then
  pass appliance acceptance with two GPU-backed `llama3.2:1b` inferences.
- Finalize VM 320 with acceptance SHA-256
  `abd996dfba91947d2be699de46ed34cce00976929c8b5cb0b485375925fa6271`.

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
