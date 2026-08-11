# Current state

## Ollama repeat-limit terminalization

The pinned Ollama v0.32.0 server has a model-independent local reporting patch
identified by `OLLAMA_V0_32_0_REPEAT_LIMIT_TERMINALIZATION_V1`. The existing
`tokenRepeat > 30` guard and all generation settings are unchanged. Guard
activation now emits `done=true`, `done_reason=repeat_limit`, retains prior
content, and stops through the existing terminal callback path. Controlled-run
evidence records this as `MODEL_REPEAT_LIMIT`; it is model behavior, not a
runtime failure, and its partial content never becomes successful
`response.txt`.

The upstream commit, patch hash, temporary distro Go toolchain, unmodified
native payload, and patched binary identity are pinned in
`config/ollama-v0.32.0-repeat-terminalization.yaml`. The source patch contains
model-free Completion and API tests plus normal-stop and cancellation
regressions. The separate clean-SSE-without-stop fallthrough remains unchanged
and documented rather than being folded into this repair.

## Idempotent controlled inference

Controlled runs require a bounded caller invocation ID. Durable state beneath
`evidence/invocations/` is claimed before Ollama launch and moves through
`CREATED`, `RUNNING`, and terminal `SUCCEEDED`/`FAILED_*` states. Re-presenting
a matching ID never relaunches inference; `bin/run-status` exposes recovery
state. Model identity, runtime policy, and accepted offload remain unchanged.

Every syntactically valid Ollama envelope retains evaluator-only evidence under
`OLLAMA_RESPONSE_META_V2` before terminality is enforced. Presence bits remain
distinct from field values for `done`, `done_reason`, counts, and durations.
Terminal success alone creates authoritative `response.txt`, whose bytes and
SHA-256 remain the exact API `response` field. A nonterminal or missing-`done`
envelope instead retains exact non-empty bytes as `partial-response.txt`, binds
that artifact and `ollama-envelope-meta.json` to the invocation and job, and
fails closed with a distinct state. `bin/run-status` exposes bounded hashes and
terminality evidence. `OLLAMA_MACHINE_RESPONSE_V1` generation transport is
unchanged, and completion evidence is never model-visible.

A terminal `repeat_limit` envelope is intentionally different from ordinary
terminal success: exact prior content is retained as evaluator-only
`partial-response.txt`, status is `FAILED_MODEL_REPEAT_LIMIT`, and the coding
parser never receives it as a completed request.

`bin/ollama-http-forensics` is a separate evaluator-only diagnostic surface
bounded to the selected Devstral artifact, fixed loopback `/api/generate`
endpoint, exact prompt file, and explicit stream boolean. It captures request
field presence, HTTP status/headers, the entire response body, ordered event
bytes, concatenated response identity, and the accepted runtime profile. It
does not parse coding requests, execute effects, or replace
`OLLAMA_MACHINE_RESPONSE_V1`.

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

## 2026-08-10 Qwen3-Coder 30B staging observation

`qwen3-coder:30b` is present in the durable Ollama model library. Its local
manifest digest is
`06c1097efce0431c2045fe7b2e5108366e43bee1b4603a7aded8f21689e90bca`;
the model layer is 18,556,688,736 bytes, architecture `qwen3moe`, 30.5B
parameters, and quantization `Q4_K_M`.

The one neutral controlled run returned a non-empty output. Ollama reported
`20%/80% CPU/GPU`, with 14,890 MiB of the 16,303 MiB GPU allocation in use.
That observation is now the exact-artifact baseline for the accepted
`GPU_PRIMARY_PARTIAL_OFFLOAD` profile defined by `gpu-cp`: at least 80% GPU and
at most 20% CPU on `cuda-compute-katra` / RTX 5070 Ti. It is not GPU-only.

`bin/run` now requires a named `--execution-policy` and validates exact manifest
digest, appliance/GPU identity, and parseable `ollama ps` processor evidence
against `config/model-runtime-profiles.tsv`; the ambiguous `--allow-cpu` switch
is retired. CPU fallback remains rejected. Raw pull, run, and post-run evidence
remains under the guest's operational `evidence/` directory.

## 2026-08-11 Devstral Small 2 24B runtime acceptance

`devstral-small-2:24b-instruct-2512-q4_K_M` is present in the durable Ollama
model library. Its local manifest digest is
`24277f07f62db8f9cb68e9dfc679ea1818a7fbac47a50eff0a701d3f645b63c8`;
the model layer is 15,177,370,240 bytes, architecture `mistral3`, 24.0B
parameters, and quantization `Q4_K_M`.

Three identical neutral machine-response probes at context 4096 returned
non-empty output and consistently reported `12%/88% CPU/GPU`, with 14,648 MiB
VRAM used. The cold run completed in 31.15 seconds and two warm repeats in 0.92
and 0.91 seconds. Host available RAM stayed above 15.0 GB with no swap, OOM,
failed unit, or harmful pressure.

`gpu-cp` accepted the exact-artifact `GPU_PRIMARY_PARTIAL_OFFLOAD` profile at
GPU >= 88% and CPU <= 12%. `bin/run` now enforces that profile independently
of the existing Qwen 80%/20% profile. Runtime acceptance does not grant coding
qualification or supervised-production admission.

## 2026-08-11 Qwen2.5-Coder 14B runtime acceptance

`qwen2.5-coder:14b-instruct-q4_K_M` is present in the durable Ollama model
library. The installed manifest SHA-256 is
`9ec8897f747e246e970bc5cfdda85d22f1123dc2e3d34978a010a75968716849`.
Its exact model blob is
`ac9bc7a69dab38da1c790838955f1293420b55ab555ef6b4615efa1c1507b1ed`,
8,988,110,784 bytes; its architecture is `qwen2`, parameter class 14.8B,
quantization `Q4_K_M`, and model context metadata 32768. The config and
template blobs also matched the selected manifest exactly.

One authorized pull ran from 17:37:15Z through 17:39:27Z. Three and only three
neutral non-streaming `/api/generate` probes then requested `num_ctx=4096`
without any other generation override. Each returned HTTP 200, `done=true`,
`done_reason=stop`, 42 prompt tokens, 6 evaluation tokens, and the exact
21-byte response whose SHA-256 is
`0c0798e15e34cfd496072aa8c7efc1958758710b3ce4b66064d9358c63ac26b8`.
The cold total duration was 4.705 seconds, including a 4.516-second load; the
warm total durations were 0.297 and 0.284 seconds. Effective context was 4096
for the loaded runner.

Ollama reported `100% GPU` placement. NVIDIA evidence observed 9,304 MiB peak
VRAM and no CPU offload. Host available RAM remained at or above
13,849,677,824 bytes with no swap. Ollama disabled mmap during the cold load
under its headroom heuristic; this did not produce a host-pressure abort or
operational degradation. Service and GPU health remained normal with no OOM,
CUDA error, XID, or failed unit.

The exact empirical profile is `qwen25-coder-14b-katra-4096`, mode `GPU_ONLY`,
bound to the manifest, Q4_K_M quantization, `cuda-compute-katra`, `hv-katra`,
and the RTX 5070 Ti. Raw evidence remains under
`/srv/gpu-compute/evidence/20260811T173705Z-task10q-qwen25-acquisition/` and
`/srv/gpu-compute/evidence/task10q-qwen25-14b-runtime-20260811/`. This is
runtime acceptance only; V2 production admission has not run.

## 2026-08-10 deployment-path retirement

`cuda-compute` is the former project/runtime name. The former deployment path
`/srv/cuda-compute` was retired after its classified runtime state and evidence
were hash-verified in
`/srv/gpu-compute-preservation-20260810T110900Z` and preserved beneath the
canonical `/srv/gpu-compute/evidence/legacy-cuda-compute/` tree. The canonical
appliance source path is `/srv/gpu-compute`, deployed from
`6906119abaeb371c37a0036d5462e599b469e146`.

This was filesystem retirement only: no model inference, CUDA/Ollama
acceptance, or runtime-policy change was executed. The VM hostname remains
`cuda-compute-katra`.

## 2026-08-10 canonical evidence-root correction

The first external controlled-run integration stopped before inference because
the migrated `/srv/gpu-compute/evidence` directory was `root:root 0755` while
the approved runner executes as `louis`.  The canonical operational contract
is now `louis:louis`, mode `0755`, for that evidence subtree only; source files
remain outside the runtime-write boundary.  A non-model create/remove probe,
storage/profile/service/output-path gates, and wrong-policy pre-inference
rejection passed after the correction.  No model inference or runtime-policy
change occurred.

## Next executable boundary

VM 320 is finalized as the RTX 5070 Ti reference appliance.  Do not redo
networking, evidence sealing, model-disk formatting, VM construction, or host
passthrough setup.  Future work should begin from a separate, explicitly
authorized production workload or maintenance play.
