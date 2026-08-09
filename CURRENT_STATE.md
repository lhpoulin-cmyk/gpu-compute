# Current state

## gpu-compute convergence

The active repository/appliance authority is **gpu-compute**. `cuda-compute`
was the original NVIDIA/CUDA implementation that established this first
accepted appliance; historical names, evidence paths, `cuda-katra`, and guest
hostname `cuda-compute-katra` remain valid provenance.

VM 9320 remains the accepted hardware-neutral Ubuntu 26.04 template and VM
320 remains the accepted RTX 5070 Ti appliance. The durable guest contract is
`/mnt/models` with `LABEL=cuda-models`, independent of the current
`cuda-katra` LVM-thin backing implementation. No storage migration is in
scope; a future Ceph RBD move is storage acceptance work, not application
redesign.

Platform observability is complete. The accepted active-workload closure at
`evidence/telemetry/20260809T184656Z-mistral-platform-closure/` recorded host
CPU busy 1.0/12.7/18.1%, loaded PCIe Gen3 x16 at 8.0 GT/s for 95/95 samples,
GPU utilization to 90%, power to 275.9 W, and GPU temperature to 70 C. CPU
starvation, PCIe starvation, thermal limitation, and CPU fallback were not
observed.

Katra also successfully served ws-doc-writer's external Alpha Trial
`trial-82224bc860c770d5` through frozen Qwen3, Gemma3, and Mistral Nemo
models. Its source, setup, attempts, prose, reviews, and SQLite state remain
ws-doc-writer authority; gpu-compute records this only as real application
workload evidence with GPU residency and no CPU fallback.

External application dependencies are ws-doc-writer
`dfb759afb7826a2b849fa95bf40ce6f06cd3cd05` (JSON-mode adapter compatibility,
local schema validation, and setup carry-forward) and ws-cp/infrastructure
`6dc02542cc1f7780d93bf12c492ad2c2d94a00d3` (Katra backend environment path).
They are recorded dependencies, not code imported into this repository.

Alpha bookkeeping is delegated to ws-doc-writer: the +7 attempt delta consists
of three grammar failures, three successful retries, and preserved
`generation-90902677ed740c58`, a Qwen response-schema-invalid attempt between
the grammar failure and successful retry. No application state was modified.

## Accepted host / VM state

Accepted:

- Phase 1 storage
- Phase 2 VFIO/reboot validation
- Phase 3 Ubuntu 26.04 template construction
- Phase 4 VM 320 construction/start
- VM 320 guest-network recovery
- encrypted SOPS/age preservation of network-recovery evidence
- 160 GiB model-disk preparation
- RTX 5070 Ti software installation, Secure Boot MOK enrollment, and appliance acceptance

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
- root disk: 64 GiB (`/` ext4, 43 GiB free after online growth)
- `nvidia-open` `610.57.04-1ubuntu1`; CUDA toolkit `13.3.1-1`
- Ollama `0.32.0` enabled only after CUDA smoke passed
- llama.cpp `b10173` / `e9fa0781f1c25fc4fe8c86be1edc6970661ad6f0`, built for `sm_120`

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

The installed driver is `nvidia-open=610.57.04-1ubuntu1`; it satisfies the
branch-610 minimum.  Secure Boot MOK enrollment was required for the locally
DKMS-built module.  `tests/smoke/cuda-nvidia` passed, including a compiled
`sm_120` CUDA kernel.  `tests/smoke/appliance` and
`tests/acceptance/appliance` passed with two `llama3.2:1b` GPU-backed
inferences.  Acceptance record SHA-256:
`abd996dfba91947d2be699de46ed34cce00976929c8b5cb0b485375925fa6271`.

## 2026-08-09 ws-doc-writer representative multi-model workload

The repaired case telemetry collector completed a 300-second closed-case capture
while ws-doc-writer v2 ran its frozen three-model, ten-case workload through
the Katra loopback Ollama backend.  The external benchmark run
`benchmark-v2-katra-20260809T182340Z` completed 30/30 outputs with the fixed
8192 context, temperature 0.2, top-p 0.9, seed 42, non-streaming, thinking-off
contract.  Raw benchmark outputs remain owned by ws-doc-writer and are not in
this repository.

Katra telemetry evidence is
`evidence/telemetry/20260809T182323Z-ws-doc-writer-3model-closed/`.  It shows
GPU temperature 37.0/47.4/68.0 C, board power 17.4/82.1/289.1 W, GPU
utilization 0.0/21.5/97.0%, graphics clock 172/1277/2872 MHz, and VRAM
2 MiB/8123 MiB/10268 MiB (min/avg/max).  CPU package was 36.0/45.4/60.0 C;
PCH 51.0/53.3/56.0 C; NVMe composite 31.9/36.9/39.9 C.  No thermal slowdown
or active power cap was reported after the run.  The collector does not sample
host CPU utilization, and the privileged PCIe query was made after load, so
the observed x16 / 2.5 GT/s link is idle-only and is not proof of load-link
speed.  No CPU fallback was observed: Ollama `/api/ps` recorded full VRAM
residency for every selected model.

## Next executable boundary

VM 320 is finalized as the RTX 5070 Ti reference appliance.  Do not redo
networking, evidence sealing, model-disk formatting, VM construction, or host
passthrough setup.  Future work should begin from a separate, explicitly
authorized production workload or maintenance play.
