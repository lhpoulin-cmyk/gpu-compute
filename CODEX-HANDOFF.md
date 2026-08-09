# Codex handoff — hv-katra GPU compute appliance

## Accepted state

The following are complete and accepted:

- Phase 1 storage
- Phase 2 VFIO/reboot validation
- Phase 3 Ubuntu 26.04 template VM 9320
- Phase 4 reference VM 320 construction/start

VM 9320 is the accepted `tpl-compute-ubuntu2604-20260808` template. Its root, EFI,
and cloud-init disks are entirely on `cuda-katra` and it was never booted before
conversion.

VM 320 is running as `cuda-compute-katra`:

- full clone of 9320;
- 8 vCPU / 16384 MiB RAM;
- 32 GiB root, EFI, cloud-init and 160 GiB `scsi1` on `cuda-katra`;
- `vmbr0`: `192.168.10.92/24`, gateway `192.168.10.1`;
- `vmbr1`: `192.168.100.92/24`, MTU 9000, no gateway;
- DNS `192.168.10.250 192.168.10.251`, search `home.arpa`;
- direct `hostpci0` passthrough of host `0000:01:00.0`.

The fixed-host reference implementation intentionally uses direct BDF passthrough.
There is no Proxmox logical PCI mapping requirement. Host preflight verifies exact
compute/audio PCI IDs and `vfio-pci` ownership before attachment.

## RTX 5070 Ti software contract

Use `config/profiles/nvidia-rtx5070ti/profile.yaml`:

- Ubuntu 26.04
- NVIDIA repository `ubuntu2604`
- `nvidia-open=610.43.02-1ubuntu1`
- acceptance minimum driver `610.43.02`
- `cuda-toolkit-13-3=13.3.1-1`
- compute capability `12.0`
- Ollama `0.32.0`, verified release asset
- llama.cpp `b10173`, exact commit
  `e9fa0781f1c25fc4fe8c86be1edc6970661ad6f0`
- llama.cpp CUDA architecture `120`
- CPU fallback rejected

The prior profile value `610.57.04-1ubuntu1` was corrected because it is not present
in the current NVIDIA Ubuntu 26.04 repository. Do not restore it without new evidence.

## Implemented guest construction path

The branch now includes the complete current RTX guest path:

- `bootstrap/prepare-model-disk.sh`
- `bootstrap/packages.sh`
- `bootstrap/stack-nvidia-modern.sh`
- `bootstrap/install-profile.sh`
- `bootstrap/install.sh`
- `tests/unit/nvidia-modern-contract.sh`

`prepare-model-disk.sh` refuses ambiguity: it requires exactly one unambiguous ~160
GiB non-root blank disk, no partitions/signatures/mounts, then creates ext4
`LABEL=cuda-models` and mounts `/mnt/models`.

The NVIDIA stack uses the official network repository/keyring, simulates the bounded
APT transaction before installation, refuses simulated removals, installs the exact
profile driver/toolkit meta versions, installs a SHA-verified Ollama release asset,
and builds the exact llama.cpp commit for `sm_120`.

Ollama is deliberately left **disabled/stopped** through driver installation and the
first reboot so it cannot silently start on CPU. Enable/start it only after
post-reboot NVIDIA smoke proves the GPU path.

## Next executable boundary — guest construction and acceptance

Start with repository validation on hv-katra, then operate on VM 320 over SSH using the
already-provisioned operator key. The source snapshot should be transferred from the
host checkout; do not install GitHub credentials in the guest.

Sequence:

1. Verify SSH access to `louis@192.168.10.92`.
2. Verify guest Ubuntu 26.04, `192.168.10.92`, `192.168.100.92`, route/DNS, and
   `lspci -nn` visibility of `10de:2c05`.
3. Record `mokutil --sb-state` when available. Secure Boot state is evidence, not by
   itself a reason to abandon the build; after driver installation verify whether the
   NVIDIA module actually loads before enabling Ollama.
4. Run `bootstrap/prepare-model-disk.sh --dry-run`; require exactly one candidate and
   review it, then run `--apply`.
5. Transfer the current host repository snapshot to `/srv/cuda-compute` without `.git`
   credentials or private keys.
6. Run:

   ```bash
   sudo /srv/cuda-compute/bootstrap/install.sh \
     --profile /srv/cuda-compute/config/profiles/nvidia-rtx5070ti/profile.yaml \
     --operator louis --dry-run
   ```

7. If the dry-run matches the profile, rerun with the default apply mode (omit
   `--dry-run`). Do not run acceptance before reboot.
8. Reboot VM 320.
9. After SSH returns, run `tests/smoke/cuda-nvidia` first. If it passes, enable/start
   Ollama:

   ```bash
   sudo systemctl enable --now ollama.service
   ```

10. Then run `tests/smoke/appliance` and `tests/acceptance/appliance`.
11. Finalize instance state only after acceptance passes.

If the NVIDIA module does not load after reboot, capture Secure Boot/DKMS/module logs
and resolve that specific condition. Do not enable Ollama or accept CPU fallback.

## Stop conditions

Stop on a genuine mismatch: wrong guest OS/network/GPU identity; ambiguous or nonblank
model disk; package simulation proposing removals; unexpected NVIDIA/CUDA candidate
versions; verified artifact hash mismatch; driver module failing to load after reboot;
compute capability not 12.0; or inability to prove GPU-backed inference.

Do not restart the retired transitive-package closure work, create a PCI resource
mapping, or mix RX 9070 XT/P6000/B70 implementation into this reference deployment.
