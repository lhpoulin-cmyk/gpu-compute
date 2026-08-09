# CUDA Compute Appliance Contract

Every deployed Helix-ARPA CUDA compute appliance is the combination of a
released repository commit, a generic VM image, an active hardware profile, a
private deployment profile, passing acceptance evidence, and generated instance
state.

## Identity

`BUILD` and `CURRENT_STATE.md` record appliance name and release, Git commit,
template version, hardware profile, deployment profile identifier, instance
hostname/name, and creation date. Values are supplied or observed; bootstrap
must not invent them.

## Required interface

Every instance provides executable `/srv/cuda-compute/bin/{doctor,probe,run,
validate-output,collect-evidence}` and the canonical `/srv/cuda-compute`
workspace. `/mnt/models/{library,work,cache,output}` are reserved mount points;
existence is never treated as proof of a mount.

## Guarantees

- Model weights are never overwritten and input/output paths differ.
- Incomplete output uses a temporary suffix and promotion follows validation.
- CUDA device, driver, and fallback policy are explicit.
- CPU fallback is rejected unless a job explicitly authorizes it.
- Output token validation, throughput recording, and provenance gate promotion.
- Job evidence and failure reason are retained.
- The greater local reserve of 20 GiB or 20 percent is enforced.
- Guest logic never changes host GPU, NVMe partition, or virtualization
  configuration.

## Acceptance

Before promotion, tests prove expected physical GPU and kernel driver, CUDA
device nodes and access, CUDA version and compute capability, Ollama service
active with CUDA backend, llama.cpp CUDA build available, synthetic CUDA
inference with expected device path, valid output, throughput recorded,
no CPU fallback, and observed `CURRENT_STATE.md`. Representative-model gates
add quantization level, VRAM headroom, thermal steady-state, repeated
invocation, production command, and rollback. Optional experimental paths
(Vulkan compute) are not acceptance gates unless the deployment profile
requires them.
