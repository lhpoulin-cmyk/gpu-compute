# AGENTS.md — Helix-ARPA CUDA Compute Appliance

## Identity and mission

This machine is a dedicated NVIDIA GPU compute appliance. It is not a
general-purpose desktop, container host, media server, or unrelated application
server. Its mission is reproducible AI model inference, CUDA workload execution,
GPU capability validation, and pipeline automation for LLM and compute tasks.

Priorities are correctness, model integrity, reproducibility, evidence,
operational reliability, then throughput. Throughput never overrides correctness
or model integrity.

## Active hardware profile

The installed `config/active-hardware-profile.yaml` defines the expected GPU,
kernel driver, CUDA version, compute capability, VRAM capacity, supported
compute APIs, production inference stack, and required validation tests.
Deployment configuration may override instance-dependent values such as the
device node. Verify the active profile and observed state at the start of every
implementation or diagnostic task. Profile declarations are expectations, not
proof that hardware is working.

## Host execution authority

The repository workspace boundary is not the host authority boundary. When the
operator explicitly authorizes a bounded host-side play on `hv-katra`, the
agent may use the host interfaces required by that play, including `qm`, `pct`,
`pvesm`, LVM/storage inspection and approved mutation, PCI/IOMMU/VFIO
inspection and approved mutation, systemd, Proxmox configuration, and guest
construction interfaces.

That authority is limited to the explicit scope and stop conditions of the
operator play. It does not authorize unrelated host changes, destructive work
outside the play, or a later deployment phase. Privilege remains separate from
authority: use the repository-approved privilege-elevation path when one is
required; do not substitute an unsafe mechanism.

A Codex sandbox denial, missing writable root, or unavailable host command is
an execution-environment limitation, not project doctrine or evidence that the
operator withheld authority. For an authorized action blocked only by the
execution environment, use the available approved escalation or full-access
path. If access genuinely cannot be obtained, report **EXECUTION ENVIRONMENT
BLOCKED** and name the exact inaccessible interface. Do not call the
installation design or operator authorization blocked merely for that reason.

Fail closed for a hardware identity mismatch, unexpected storage state,
unexpected PCI endpoint, conflicting control-plane authority, destructive work
outside the authorization, or unresolved required design input. Do not stop
solely because an authorized action operates outside `/srv/cuda-compute`.

## Guest runtime boundary

Inside VM 320, guest logic may inspect and modify only approved guest packages,
configuration, scripts, tests, documentation, and inference services. It must
not independently alter host GPU, storage, virtualization, VFIO, IOMMU, PCI
passthrough, physical-disk, network, other-VM, or resource-mapping state. A
host-side change requires an explicit operator-authorized host play.

## Workspace and storage

The canonical workspace is `/srv/gpu-compute`. Supported commands are in
`bin/`; versioned profiles in `config/`; policy and runbooks in `docs/`; raw
evidence in `evidence/`; state transitions in `jobs/`; runtime logs in `logs/`;
pipeline definitions in `pipelines/`; bounded work in `scratch/`; validation in
`tests/`; and disposable task files in `tmp/`.

Reserved external paths are `/mnt/models/library`, `/mnt/models/work`,
`/mnt/models/cache`, and `/mnt/models/output`. Their existence does not prove a
mount exists. Verify the exact mount with `findmnt -M` before access or writes.

Before substantial output verify destination filesystem, available bytes and
inodes, expected model or output size, scratch use, and mount state. Local
workspace storage must retain whichever reserve leaves more free capacity:
20 percent or 20 GiB. Never redirect model downloads or large inference outputs
to the root filesystem because an external mount is absent.

## Model integrity

Models under `/mnt/models/library` are read-only for inference. Never overwrite,
destructively rename, delete, or modify source model files during a job. A
failed inference job never removes its model input. Prefer read-only library
mounts. Read models from library, write outputs to a distinct work or output
path, validate, then promote separately. Deletion and archival are independent
operator decisions.

## Hardware acceleration

CUDA version, driver, device node, and compute capability must be explicitly
verified before inference. Software CPU fallback is prohibited unless a job
explicitly authorizes it. Never silently fall back to CPU or a different device.
If CUDA initialization fails, fail clearly and preserve complete logs.
`nvidia-smi` reporting a device and `nvcc` compiling are not proof of
inference acceleration; confirm the intended CUDA path from framework logs and
telemetry.

## Output and job state

Every production record contains the framework version, full command, GPU
identity, CUDA version, active model and quantization, VRAM allocated, relevant
driver version, timestamps, exit status, output token count or file, and
throughput. Jobs move `queued → running → succeeded` or
`queued → running → failed`, have a unique ID, and retain request, environment,
logs, results, status, and failure reason.

Raw evidence belongs under `evidence/<timestamp>-<change-id>/`. Never rewrite
raw evidence; add a correction that references it. Do not commit raw evidence,
logs, runtime job state, model weights, generated outputs, credentials, or
secrets.

## Bounded changes and packages

For nontrivial changes: observe; record original state; state intent; identify
rollback; apply the smallest change; test exact function; regress production;
record evidence; update `CURRENT_STATE.md`; commit sanitized artifacts.

Prefer Ubuntu repository packages and official NVIDIA CUDA toolkit packages.
Before package changes record installed and candidate versions, origins,
dependencies, holds, active CUDA toolkit, proposed removals, and rollback path.
Never run a broad unattended distribution upgrade for a focused repair. Do not
add repositories or compile CUDA drivers, Ollama, or llama.cpp outside approved
bootstrap without documented need, rollback, and operator authorization.

## Script standards

Shell scripts use `#!/usr/bin/env bash`, `set -Eeuo pipefail`, quoted variables,
required-argument and command checks, explicit paths, machine-readable data
where available, useful errors, and nonzero failure status. They avoid input
deletion, write temporary output before promotion, expose stderr, retain failed
logs, and are safe to rerun where practical. Overwrite or deletion requires
explicit confirmation and a documented dry-run mode.

## Testing

Smoke tests check workspace, active profile, required commands, NVIDIA tools,
expected device access, driver, and CUDA/Vulkan exposure. Regression tests add
a synthetic CUDA kernel execution, Ollama model load, tokenizer round-trip, and
fallback rejection. Acceptance tests add physical GPU identity, representative
model, quantization level, throughput, thermal/error observation, repeated
invocation, production command, and rollback.

CPU-fallback failure does not fail appliance acceptance unless the deployment
profile explicitly requires it.

## Documentation and stop conditions

After an approved change update `CURRENT_STATE.md`, relevant runbook/profile,
and `CHANGELOG.md`. "Works" must name command, CUDA version, model,
quantization, validated output, tokens/second, and versions.

Stop when the machine or expected GPU is wrong; device node changes
unexpectedly; model integrity is at risk; a required mount is absent; free space
is below reserve; a package action removes the CUDA stack; host changes,
repartitioning, or an unapproved repository are required; production regression
or output validation fails; or CPU fallback cannot be ruled out.

## Definition of done

A task is complete only when intended CUDA acceleration and output validation
succeed, production remains explicit, no model was modified, no silent fallback
occurred, regression passes, evidence and documentation are current, rollback
is known, and remaining limitations are stated.
