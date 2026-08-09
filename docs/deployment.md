# Deployment

## Accepted prerequisites

The current hv-katra reference deployment begins from the accepted Phase 1--3 state:

- dedicated Proxmox LVM-thin storage `cuda-katra` on the approved 256 GiB SN5100 allocation;
- RTX 5070 Ti host functions bound to `vfio-pci`;
- logical Proxmox PCI mapping `gpu-compute-rtx5070ti`;
- healthy `vmbr0` and `vmbr1` (`vmbr1` MTU 9000);
- accepted Ubuntu 26.04 template VM 9320, `tpl-compute-ubuntu2604-20260808`.

VM 9320 is an OS template only. It contains no GPU software, repository checkout,
model disk, or production identity.

## Concrete reference profile

Use:

```text
proxmox/hv-katra-rtx5070ti.yaml
```

It defines the non-secret VM 320 contract:

- VMID 320 / `cuda-compute-katra`;
- full clone of template 9320;
- 8 vCPU / 16384 MiB RAM;
- root and 160 GiB model disk on `cuda-katra`;
- `192.168.10.92/24` on `vmbr0`, gateway `192.168.10.1`;
- `192.168.100.92/24` on `vmbr1`, MTU 9000, no gateway;
- DNS `192.168.10.250 192.168.10.251`;
- search domain `home.arpa`;
- logical PCI mapping `gpu-compute-rtx5070ti`.

`proxmox/example-profile.yaml` is retired example material and is not executable.

## Operator SSH access

The only runtime identity input required by the deploy script is a readable SSH
**public-key** file. It is passed with:

```bash
--ssh-public-key-file /path/to/operator.pub
```

Do not pass or commit a private key. The deployment script rejects files containing
private-key material and does not use GitHub credentials, passwords, or tokens.

## Dry-run and deployment

First render the complete proposed mutation:

```bash
proxmox/deploy-instance.sh \
  --profile proxmox/hv-katra-rtx5070ti.yaml \
  --ssh-public-key-file /path/to/operator.pub \
  --dry-run
```

The dry-run must show only:

1. full clone 9320 -> 320 on `cuda-katra`;
2. CPU/RAM and two NIC configuration;
3. 160 GiB `scsi1` on `cuda-katra`;
4. standard Proxmox cloud-init identity/network configuration;
5. logical RTX 5070 Ti PCI mapping attachment;
6. optional VM start.

After review, apply:

```bash
proxmox/deploy-instance.sh \
  --profile proxmox/hv-katra-rtx5070ti.yaml \
  --ssh-public-key-file /path/to/operator.pub \
  --apply
```

Use `--no-start` when the VM should remain stopped after construction.

Before mutation the script verifies the accepted template, target VMID/name,
`cuda-katra` capacity, both bridges, MTU, logical PCI mapping availability, exact RTX
5070 Ti PCI identities, and host `vfio-pci` binding. If failure occurs after VM creation,
the partial VM is preserved for evidence instead of being silently destroyed.

## First-boot boundary

The deployment script does **not**:

- format the 160 GiB model disk;
- install CUDA or NVIDIA guest packages;
- clone the private GitHub repository inside the guest;
- run Ollama/llama.cpp acceptance;
- finalize instance state.

After first boot, a separate play must:

1. verify Ubuntu 26.04 and both static network identities;
2. prove the RTX 5070 Ti is visible to the guest;
3. identify `scsi1` unambiguously, format it as the approved filesystem with label
   `cuda-models`, and mount it at `/mnt/models`;
4. transfer the current repository source to `/srv/cuda-compute` without copying
   private GitHub credentials into the guest;
5. run the RTX 5070 Ti package simulation and bootstrap;
6. reboot if required;
7. run smoke and hardware acceptance;
8. finalize instance state only after acceptance passes.

Acceptance, not VM creation or driver installation, promotes VM 320 into the reference
appliance.
