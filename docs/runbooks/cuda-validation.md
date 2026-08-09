# Runbook: CUDA Validation

**Guest**: `cuda-compute-katra` (VM 320)
**Pinned toolkit**: CUDA 13.3
**GPU**: RTX 5070 Ti, compute capability 12.0

## Driver and toolkit

```bash
nvidia-smi --query-gpu=name,driver_version,memory.total,compute_cap --format=csv,noheader
nvcc --version
```

Acceptance requires:

- GPU name contains `GeForce RTX 5070 Ti`;
- compute capability is exactly `12.0`;
- driver is `610.43.02` or later;
- `nvcc` reports CUDA release `13.3`.

## Actual CUDA execution

Run:

```bash
tests/smoke/cuda-nvidia
```

The smoke test compiles and executes a small CUDA kernel, checks the returned
value, and confirms the runtime-reported device compute capability is 12.0.
This replaces reliance on metadata-only checks such as `nvidia-smi` alone.

## llama.cpp CUDA backend

```bash
llama-cli --version
llama-cli --list-devices
```

Expected: pinned tag `b10173` and a line containing `CUDA0` plus RTX 5070 Ti.

## Ollama GPU path

```bash
ollama pull llama3.2:1b
ollama run llama3.2:1b 'Return VERIFIED.'
ollama ps
```

The active model must be reported on GPU. `bin/run` fails closed if it cannot
prove GPU residency through `ollama ps` and CPU fallback was not explicitly
allowed.

## Acceptance

```bash
tests/acceptance/appliance
```

Acceptance runs the CUDA smoke suite, performs two GPU-only Ollama invocations,
validates outputs, records driver/toolkit/software versions and post-run GPU
temperature, and writes a machine-readable record under `tests/results/`.
