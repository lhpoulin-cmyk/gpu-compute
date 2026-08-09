# Codex handoff — hv-katra CUDA compute appliance

## Scope

Bring up the reusable CUDA compute appliance on `hv-katra` from this repository.
Do not improvise host storage, PCI identity, network identity, or software
versions. Fresh 2026-08-08 LifeTap evidence is the deployment baseline.

## Evidence-backed hv-katra facts

- Proxmox VE: 9.2.2
- Kernel: 7.0.14-6-pve
- CPU: Intel Core i7-9700KF, 8 logical CPUs
- RAM: ~31.3 GiB
- `vmbr0`: UP/LOWER_UP, `192.168.10.21/24`, MTU 1500
- `vmbr1`: UP/LOWER_UP, `192.168.100.21/24`, MTU 9000; guest interfaces are forwarding
- A stale boot-journal reference to `enp2s0` is configuration drift, not evidence that `vmbr1` is down.
- RTX 5070 Ti compute function: `0000:01:00.0`, PCI ID `10de:2c05`
- NVIDIA HDA companion function: `0000:01:00.1`, PCI ID `10de:22e9`
- Both GPU functions are in IOMMU group 1.
- Sandisk Optimus 5100 1TB: serial `26100U800434`, stable by-id
  `nvme-Sandisk_Optimus_5100_1TB_26100U800434`; observed blank at capture time.

The source evidence hash is recorded under `docs/evidence/`.

## Frozen deployment contract

### Host storage

Allocate exactly the first 256 GiB of the blank Optimus 5100 to this appliance.
Create Proxmox LVM-thin storage `cuda-katra` there. Leave the remaining device
capacity untouched.

- VM 9320 root disk: 32 GiB on `cuda-katra`; temporary template retained 90 days.
- VM 320 root disk: 32 GiB on `cuda-katra`.
- VM 320 model/data disk: 160 GiB on `cuda-katra`.
- No substantial VM 320 disk allocation belongs on hv-katra's boot storage.
- Do not raw-pass the NVMe or its partition into the guest.

Use `proxmox/nvme-provision.sh` only after its preflight confirms the exact
serial/by-id and that the target remains blank, unused, unmounted, unsigned,
and outside existing LVM/Proxmox storage.

### GPU passthrough

Bind both IOMMU-group GPU functions to VFIO:

```text
10de:2c05  RTX 5070 Ti compute/display
10de:22e9  NVIDIA HDA companion audio
```

Create logical Proxmox PCI mapping `gpu-compute-rtx5070ti` for the compute
function `01:00.0`. The audio function is bound with the group and may remain
parked unless later explicitly required by the guest. Do not substitute a
hard-coded physical PCI address in the generic appliance source.

### VM 320

- VMID: 320
- hostname: `cuda-compute-katra`
- vCPU: 8
- RAM: 16384 MiB
- root disk: 32 GiB on `cuda-katra`
- data disk: 160 GiB on `cuda-katra`, formatted in the guest and mounted at
  `/mnt/models` by filesystem label
- NIC 1: `vmbr0`, `192.168.10.92/24`, default gateway on this interface only
- NIC 2: `vmbr1`, `192.168.100.92/24`, MTU 9000, no default gateway
- DNS: `192.168.10.250`, `192.168.10.251`
- search domain: `home.arpa`

Deployment preflight must verify that both configured bridges are presently UP;
for `vmbr1`, verify MTU >= 9000. Do not reinterpret the stale `enp2s0` journal
message as bridge failure while the bridge itself is UP/LOWER_UP.

## Frozen software stack

- Guest OS: Ubuntu 26.04 LTS x86_64
- NVIDIA package path: official CUDA network repository for `ubuntu2604`
- NVIDIA driver package: `nvidia-open`
- Required installed driver version: >= 610.43.02
- CUDA toolkit: pinned 13.3 (`cuda-toolkit-13-3`)
- RTX 5070 Ti required compute capability: 12.0
- Ollama: 0.32.0
- llama.cpp: `ggml-org/llama.cpp` ref `b10173`
- llama.cpp CUDA architecture: 120 (`sm_120`)

Do not float these versions during this installation. A future upgrade is a
separate reviewed change.

## Execution phases

## Current checkpoint

- Phase 1 storage: **ACCEPTED**.
- Phase 2 VFIO/reboot validation: **ACCEPTED**.
- Phase 3 template build: **NOT STARTED**.
- Phase 3A contract freeze: **BLOCKED**. Accepted Ubuntu/NVIDIA/Ollama/llama.cpp provenance is recorded in Phase 3A evidence; the isolated APT resolver must be corrected to use only Ubuntu snapshot `20260808T230000Z` before producing a CUDA closure lock.

### Phase 0 — preflight only

1. Verify fresh LifeTap evidence and its SHA-256.
2. Verify current NVMe identity/state before any partition mutation.
3. Verify `vmbr0` and `vmbr1` state and MTU.
4. Verify RTX functions and IOMMU group.
5. Verify no target VMID/storage/resource mapping conflict.
6. Stop on any identity mismatch.

### Phase 1 — host preparation

1. Provision `cuda-katra` from the approved 256 GiB NVMe allocation.
2. Configure VFIO for both NVIDIA functions and reboot if required.
3. Prove both functions are bound as intended after reboot.
4. Create/verify logical resource mapping `gpu-compute-rtx5070ti`.

### Phase 2 — template 9320

Build a clean Ubuntu 26.04 VM with one 32 GiB root disk on `cuda-katra` and a
single `vmbr0` NIC. It has no GPU, no model disk, no instance identity, and no
model data.

Run the repository installer in `--template-mode`. Template mode installs the
pinned CUDA toolkit, Ollama release, and pinned llama.cpp build but does not
require GPU presence, does not activate the NVIDIA driver for hardware that is
not attached, and leaves Ollama disabled. Sanitize the template without deleting
`BUILD`, then convert VM 9320 to a template.

### Phase 3 — deploy VM 320

Clone only from VM 9320 onto `cuda-katra`. Configure VM identity/resources,
both NICs, logical GPU mapping, and the 160 GiB second virtual disk. Do not attach
raw host NVMe storage.

Inside VM 320, format the second disk with the approved filesystem label and
mount it at `/mnt/models`. Run the non-template bootstrap to install/activate the
pinned `nvidia-open` driver, then reboot.

### Phase 4 — acceptance

Run:

```bash
bin/doctor
tests/smoke/appliance
tests/smoke/cuda-nvidia
tests/acceptance/appliance
```

Acceptance must prove all of the following:

- exact RTX 5070 Ti identity
- compute capability exactly 12.0
- CUDA toolkit exactly 13.3
- driver >= 610.43.02
- a compiled CUDA kernel executes successfully on the GPU
- llama.cpp enumerates the CUDA device
- `/mnt/models` is mounted and writable with reserve headroom
- repeated Ollama inference succeeds
- Ollama reports GPU processing rather than unproven CPU fallback
- acceptance outputs and YAML evidence are hashed

The small acceptance model is not the production sizing policy. Do not use a
70B model as the reference acceptance workload for this 16 GiB card.

### Phase 5 — finalize

Pass the SHA-256 of the acceptance YAML record to
`bootstrap/finalize-instance.sh`. Finalization must write
`config/instance-state.yaml` and preserve the appliance `BUILD` record.

## Stop conditions

Stop and return evidence rather than guessing if any of these occur:

- NVMe serial/by-id, blank-state, partitioning, mount, holder, LVM, or Proxmox
  storage state differs from the approved preflight.
- RTX PCI IDs or IOMMU grouping differ from the evidence above.
- `vmbr0` or `vmbr1` is not operational at deployment time, or `vmbr1` MTU is
  below 9000.
- The guest does not receive the intended two network identities.
- Compute capability is not 12.0.
- CUDA toolkit is not exactly 13.3.
- NVIDIA driver is below 610.43.02.
- Any acceptance test reports CPU fallback/unproven GPU execution.
- Finalization cannot bind the accepted evidence hash to instance state.
