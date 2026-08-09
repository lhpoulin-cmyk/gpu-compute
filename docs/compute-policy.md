# Compute Policy

## Inference integrity

Every inference job has an explicit model path, quantization, and request. The
appliance never infers a model selection from ambient state. A failed job never
modifies its model input. Results are written to a distinct output path and
validated before promotion.

## Hardware acceleration policy

CUDA is the production inference backend. The CUDA device, driver version, and
compute capability must be verified before every job. CPU fallback is rejected
unless a job's manifest field `allow_cpu_fallback: true` is set explicitly and
the operator has authorized it. Ollama and llama.cpp must log the CUDA device
path; absence of a device path in the inference log is a validation failure.

Vulkan compute is available as an experimental path. It must be explicitly
selected; it is not a fallback for CUDA failures.

## Model integrity

Models under `/mnt/models/library` are treated as read-only. The appliance
never modifies, renames, or deletes model files during inference. If a model
file is found to be corrupt or mismatched against its expected SHA-256, the job
fails immediately and the model path is reported; no remediation is attempted
by the appliance.

## Storage reserve

At the start of every job, the appliance verifies that `/mnt/models` has at
least the greater of 20 GiB or 20 percent free. If the reserve is not met,
the job is rejected before inference begins.

## VRAM headroom

The appliance checks that expected model VRAM requirements do not exceed
available VRAM before beginning inference. Layer-offload to system RAM is
permitted only when the hardware profile's `allow_partial_offload` flag is
set. Full VRAM offload is the production requirement.

## Output completeness

Output is not complete until:
- Inference exit status is zero.
- Output is non-empty and contains the expected structure.
- CUDA device path is confirmed in logs.
- Throughput (tokens/second) is recorded.
- SHA-256 of the output is computed.
- Provenance record is written.

Partial or intermediate output uses a `.part` suffix. Promotion removes the
suffix atomically on the same filesystem only after all checks pass.

## Evidence retention

Every job retains full logs, the exact command, model path and SHA-256,
CUDA version, driver version, throughput, output path and SHA-256, and failure
reason if applicable. Evidence is append-only and is never rewritten.
