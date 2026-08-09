# gpu-compute Ownership Contract

## Purpose

`gpu-compute` owns the compute appliance between verified model intake and a
validated inference result or compute output suitable for downstream consumption.

Its conceptual input boundary is `MODEL_READY`.

Its conceptual terminal boundary is `OUTPUT_VALIDATED`.

These names define repository ownership. They are not claims that equivalent
runtime constants or a finalized cross-repository schema already exist.

## Authoritative supporting contracts

Detailed appliance and security behavior remains governed by:

- `docs/appliance-contract.md`
- `docs/security-boundary.md`

This document summarizes repository ownership and must not silently override
those contracts.

## Owned by gpu-compute

- Validation of an explicitly supplied model and inference request.
- Creation and tracking of compute jobs.
- CUDA-accelerated inference via Ollama and llama.cpp.
- Vulkan compute path validation.
- Output validation, token counting, and throughput recording.
- Checksums and immutable job evidence.
- Production of a policy-complete output suitable for downstream use.
- Refusal of incomplete, fallback, or unverifiable compute paths.
- Manifest production through the repository's versioned manifest machinery.
- Tests proving inference, validation, and fail-closed behavior.

## Not owned by gpu-compute

`gpu-compute` does not:

- Pull, curate, or canonically store model weights.
- Own model identity, quantization selection, or provenance outside of the
  active hardware profile.
- Serve a public API or manage external user sessions.
- Independently choose NVMe partition layout or raw disk assignment.
- Independently choose GPU passthrough, IOMMU groups, or VFIO binding.
- Write to served application paths outside `/mnt/models/output`.
- Import or invoke `agentctl` as an internal library.
- Promote finalized outputs to external consumers.

## Runtime and development topology

- `cuda-compute-katra` is the CUDA compute appliance and current reference.
- The passed-through NVIDIA GeForce RTX 5070 Ti is owned by this appliance.
- `hv-katra` owns the physical NVMe and host LVM-thin storage. The authorized 256 GiB allocation is external infrastructure.
- `gpu-compute` may consume virtual disks from `cuda-katra`. An explicitly
  operator-authorized host-side play may perform the exact approved host
  partition/LVM mutation; that execution authority does not transfer ongoing
  infrastructure ownership to the repository or guest runtime.

## Upstream boundary

```text
operator --MODEL_READY--> gpu-compute
```

The operator supplies a validated model path, quantization, and request.
`gpu-compute` independently validates the model integrity and request before
beginning work. It must fail closed when the model, request, or evidence is
incomplete.

## Downstream boundary

```text
gpu-compute --OUTPUT_VALIDATED--> downstream consumer
```

A completed output may be used downstream only after validation passes and the
manifest and evidence are produced.

## Invariants

- Fail closed on incomplete input, output, policy, or evidence.
- Model weights are never deleted as a side effect of inference.
- Output is not complete until validation succeeds.
- Checksums refer to finalized bytes.
- Manifests are versioned, explicit, and reproducible.
- Evidence is append-only for consequential state transitions.
- Dry-run behavior is genuinely read-only.
- No silent CPU fallback or alternate device substitution.
- Git is ground truth for code, contracts, schemas, and reviewed policy.

## Review fence

A change requires explicit architectural review if it introduces:

- Model weight management or curation logic.
- External API serving or multi-tenant session management.
- NVMe partition or raw disk control.
- GPU passthrough or VFIO configuration.
- Output promotion to external systems.
- An internal dependency on `agentctl` or external orchestration frameworks.
- Release of unvalidated or CPU-fallback output.
- Model weight deletion.
- Unwitnessed consequential state mutation.
