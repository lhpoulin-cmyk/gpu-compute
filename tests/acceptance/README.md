# Acceptance tests

Acceptance tests gate promotion of a clone from VM 9320 into an accepted
appliance instance. They must be run after:

1. GPU passthrough is active and confirmed by `nvidia-smi`.
2. NVMe partition is mounted at `/mnt/models`.
3. Bootstrap (`bootstrap/install.sh --apply`) has completed.
4. VM has been rebooted with the NVIDIA driver active.

Run `tests/acceptance/appliance` from within the guest. The test will:
- Run smoke prereqs.
- Confirm physical GPU identity (RTX 5070 Ti) and compute capability (12.0).
- Confirm VRAM >= 15 GiB.
- Confirm model storage is writable and meets the reserve.
- Run a synthetic CUDA inference via Ollama with `llama3.2:1b`.
- Validate output is non-empty and contains the expected sentinel.
- Confirm CUDA (not CPU) backend was used.
- Emit the output SHA-256 for recording in `CURRENT_STATE.md`.

`tests/acceptance/record.example.yaml` shows the structure of an acceptance
record. Populate one and commit it to this repository after acceptance passes.
