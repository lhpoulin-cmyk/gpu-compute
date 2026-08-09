# Codex handoff — hv-katra GPU compute appliance

## Accepted state

The following phases are complete and accepted:

- Phase 1 storage: **ACCEPTED**
- Phase 2 VFIO/reboot validation: **ACCEPTED**
- Phase 3 Ubuntu 26.04 template construction: **ACCEPTED**

`cuda-katra` remains the dedicated LVM-thin store on the approved first 256 GiB of
the Sandisk Optimus 5100. The remaining ~675.5 GiB remains unpartitioned. `vmbr0`
and `vmbr1` are healthy; `vmbr1` is MTU 9000. RTX 5070 Ti compute/audio functions
remain bound to `vfio-pci`; the upstream root port remains host-owned by `pcieport`.

VM 9320 is the accepted reusable modern OS template:

- `tpl-compute-ubuntu2604-20260808`
- Ubuntu 26.04 Canonical cloud image, release serial `20260612`
- verified SHA-256 `0c9fb915bab0b36b361d3bf8aeae2115dda19d81a306656964de048033481670`
- q35 + OVMF, 8 vCPU, 16384 MiB RAM
- 32 GiB root, EFI, and cloud-init disks on `cuda-katra`
- `vmbr0` only
- no GPU/model disk/production identity
- never booted before template conversion

The apparent thin-LV stall during Phase 3 was only a disconnected execution session;
Proxmox continued and completed successfully without retry or repair.

## Phase 4 deployment surface — IMPLEMENTED

The repository now contains the reviewed non-secret VM 320 deployment profile:

```text
proxmox/hv-katra-rtx5070ti.yaml
```

and the corrected deployment implementation:

```text
proxmox/deploy-instance.sh
```

The old `proxmox/example-profile.yaml` is retired example material and must not be
executed.

The deployment script uses standard Proxmox cloud-init fields instead of committed
custom snippet files. Its only runtime identity input is a readable SSH **public-key**
file supplied with `--ssh-public-key-file`. It rejects private-key material and does
not require GitHub credentials.

Run repository validation before live deployment:

```bash
tests/unit/template-contract.sh
tests/unit/deployment-contract.sh
find . -type f -name '*.sh' -print0 | xargs -0 -n1 bash -n
git diff --check master...HEAD
```

## Next executable boundary — create VM 320

Target contract:

- VMID: 320
- name/hostname: `cuda-compute-katra`
- source: full clone of template 9320
- node: `hv-katra`
- 8 vCPU / 16384 MiB RAM
- root remains entirely on `cuda-katra`
- second virtual disk: 160 GiB on `cuda-katra`
- future filesystem label: `cuda-models`
- future mount: `/mnt/models`
- NIC 1: `vmbr0`, `192.168.10.92/24`, gateway `192.168.10.1`
- NIC 2: `vmbr1`, `192.168.100.92/24`, MTU 9000, no gateway
- DNS: `192.168.10.250`, `192.168.10.251`
- search domain: `home.arpa`
- logical PCI mapping: `gpu-compute-rtx5070ti`
- hardware profile: `config/profiles/nvidia-rtx5070ti/profile.yaml`

Before mutation the deploy script verifies:

- running on `hv-katra`;
- accepted template 9320 still matches its neutral storage/attachment contract;
- VMID/name unused;
- `cuda-katra` active with deployment reserve;
- both bridges operational and `vmbr1` MTU >= 9000;
- logical PCI mapping exists and appears unused;
- exact RTX 5070 Ti compute/audio PCI identities;
- both RTX functions remain bound to `vfio-pci`.

Use an operator-owned public key file outside the repository:

```bash
proxmox/deploy-instance.sh \
  --profile proxmox/hv-katra-rtx5070ti.yaml \
  --ssh-public-key-file /path/to/operator.pub \
  --dry-run
```

After reviewing the rendered mutation, execute the same command with `--apply`.
Use `--no-start` if VM 320 should remain stopped after construction.

The deployment implementation will:

1. full-clone 9320 -> 320 on `cuda-katra`;
2. configure CPU/RAM and both NICs;
3. add 160 GiB `scsi1` on `cuda-katra`;
4. configure standard Proxmox cloud-init user, public key, DNS, and static networking;
5. attach logical PCI mapping `gpu-compute-rtx5070ti`;
6. validate the resulting VM configuration;
7. start VM 320 unless `--no-start` was requested.

If failure occurs after VM creation, preserve the partial VM for evidence rather than
destroying it automatically.

## Post-boot boundary

Do not mix post-boot appliance construction into the VM-creation transaction.
After VM 320 boots, a separate play must:

1. verify Ubuntu 26.04 and both network identities;
2. prove the passed-through RTX 5070 Ti is visible;
3. identify the blank 160 GiB `scsi1` disk unambiguously;
4. format it with label `cuda-models` and mount it at `/mnt/models`;
5. transfer the current repository source to `/srv/cuda-compute` without copying
   private GitHub credentials into the guest;
6. run bounded RTX 5070 Ti package simulation/bootstrap;
7. install CUDA 13.3 / NVIDIA open driver stack and pinned application software;
8. reboot if required;
9. run smoke and hardware acceptance;
10. finalize instance state only after acceptance passes.

Acceptance—not VM creation or driver installation—promotes VM 320 into the reference
appliance.

## Other GPU profiles

- RX 9070 XT: Ubuntu 26.04 / ROCm 7.14 / `gfx1201`; design-stage until local testing.
- future Arc Pro B70: may use the modern Ubuntu 26.04 template when a B70 is local; no current work required.
- Quadro P6000: legacy Ubuntu 24.04 disposable root/template only when actually tested.

## Stop conditions

Stop on genuine material mismatch: wrong template/storage identity, VMID/name collision,
broken bridge, changed SN5100 boundary, missing/incorrect PCI mapping, unexpected GPU
identity or host driver, insufficient storage reserve, inability to establish intended
network identity, model-disk ambiguity, unsafe package transaction, or inability to
prove GPU-backed compute without CPU fallback.
