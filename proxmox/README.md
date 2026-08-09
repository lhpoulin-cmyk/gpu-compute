# Proxmox tooling

These scripts are reviewed host-side tooling. Run them only on an authorized
Proxmox host after `--dry-run` review. They never use VM 320 as a clone source,
never embed a physical PCI address, and refer to GPUs through logical Proxmox
resource mappings.

`sanitize-template.sh` is the sole guest-side exception and is guarded for
template VM 9320 candidates only.

## Prerequisites

Before any script runs:

1. Dedicated CUDA LVM-thin storage provisioned on the authorized SN5100 partition: `nvme-provision.sh --dry-run` then `--apply`.
2. Proxmox resource mapping `gpu-compute-rtx5070ti` created under
   Datacenter → Resource Mappings → PCI Devices.
3. Template VM 9320 built and converted: `qm template 9320`.

## Typical flow

```
nvme-provision.sh       # provision SN5100 256 GiB partition as cuda-katra LVM-thin storage
create-template.sh      # render template VM 9320 creation commands
                        # (install Ubuntu, bootstrap --template-mode, sanitize, qm template 9320)
deploy-instance.sh      # clone 9320 → 320 on cuda-katra, add model virtual disk + GPU, start
                        # (guest: bootstrap/install.sh, reboot, accept)
capture-reference.sh    # snapshot VM 320 post-acceptance state
```
