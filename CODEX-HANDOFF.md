# Codex handoff — hv-katra GPU compute appliance

## Accepted state

Complete and accepted:

- Phase 1 storage
- Phase 2 VFIO/reboot validation
- Phase 3 Ubuntu 26.04 template VM 9320
- Phase 4 reference VM 320 construction/start
- VM 320 guest-network recovery
- encrypted SOPS/age preservation of the recovery evidence
- model disk preparation on `/dev/sdb`

VM 320 is running as `cuda-compute-katra` with recovered conventional MAC-bound
netplan networking:

- `ens18`: `192.168.10.92/24`, gateway `192.168.10.1`
- `ens19`: `192.168.100.92/24`, MTU 9000, no gateway
- DNS `192.168.10.250 192.168.10.251`, search `home.arpa`
- direct RTX 5070 Ti passthrough, PCI ID `10de:2c05`
- `/dev/sdb`: ext4, `LABEL=cuda-models`, mounted `/mnt/models`
- Secure Boot: enabled

The network-recovery evidence is stored encrypted under `evidence/encrypted/` using
SOPS + age. The documented recipient fingerprint is
`SHA256:KxikWTJFxJlSqVuesl9uTE5UDd+Rq0MEyxIE4DB3nhU`.

## RTX 5070 Ti software contract

Use `config/profiles/nvidia-rtx5070ti/profile.yaml`:

- Ubuntu 26.04
- NVIDIA repository `ubuntu2604`
- `nvidia-open=610.57.04-1ubuntu1`
- acceptance minimum driver `610.57.04`
- `cuda-toolkit-13-3=13.3.1-1`
- compute capability `12.0`
- Ollama `0.32.0`, verified release asset
- llama.cpp `b10173`, exact commit
  `e9fa0781f1c25fc4fe8c86be1edc6970661ad6f0`
- llama.cpp CUDA architecture `120`
- CPU fallback rejected

The earlier `610.43.02-1ubuntu1` pin was superseded by live authenticated repository
evidence showing candidate `610.57.04-1ubuntu1`. The installer correctly stopped
before mutation on that mismatch. The current profile now tracks the observed live
candidate exactly.

## Implemented guest construction path

The branch contains:

- `bootstrap/prepare-model-disk.sh`
- `bootstrap/packages.sh`
- `bootstrap/stack-nvidia-modern.sh`
- `bootstrap/install-profile.sh`
- `bootstrap/install.sh`
- `tests/unit/nvidia-modern-contract.sh`

The NVIDIA stack uses the official NVIDIA network repository/keyring, simulates the
bounded APT transaction before installation, refuses simulated removals, installs the
exact profile driver/toolkit versions, installs a SHA-verified Ollama release asset,
and builds the exact llama.cpp commit for `sm_120`.

Ollama remains disabled/stopped until after the required reboot and successful NVIDIA
GPU smoke test.

## Next executable boundary — resume guest installation

Do not redo network recovery, evidence sealing, or model-disk formatting.

1. Sync the host branch and transfer the updated source snapshot to
   `/srv/cuda-compute` in VM 320 without `.git` or GitHub credentials.
2. Run repository regression/syntax checks.
3. Re-run the RTX bootstrap dry-run. Require live candidates:
   `nvidia-open=610.57.04-1ubuntu1` and
   `cuda-toolkit-13-3=13.3.1-1`, with no simulated removals.
4. Apply the install.
5. Reboot VM 320.
6. After SSH returns, run `tests/smoke/cuda-nvidia` first.
7. If Secure Boot prevents the NVIDIA module from loading, capture the specific
   DKMS/module-signing/MOK evidence and repair only that condition. Do not disable
   Secure Boot preemptively.
8. Only after CUDA/NVIDIA smoke passes, enable/start Ollama.
9. Run `tests/smoke/appliance` and `tests/acceptance/appliance`.
10. Finalize instance state only after acceptance passes.

## Stop conditions

Stop only for a genuine mismatch: package removals, another authenticated candidate
change, artifact hash mismatch, NVIDIA module failure after reboot, compute capability
mismatch, or inability to prove GPU-backed inference.

Do not recreate VM 320, reformat the model disk, redo the network recovery, create a
PCI resource mapping, or resume the retired transitive-package closure experiment.
