# Proxmox tooling

These scripts are reviewed host-side tooling. Run them only on an authorized Proxmox
host after `--dry-run` review. They never use VM 320 as a clone source and refer to
GPUs through logical Proxmox resource mappings.

## Current construction flow

```text
nvme-provision.sh       # accepted Phase 1: cuda-katra LVM-thin storage
create-template.sh      # Phase 3: verify/import Ubuntu 26.04 cloud image and
                        # convert unbooted VM 9320 directly to a template
deploy-instance.sh      # later: clone 9320 -> VM 320, add model disk/GPU/network
capture-reference.sh    # later: snapshot an accepted reference instance
```

VM 9320 is an OS template only. It is never booted before conversion and therefore
requires no guest bootstrap or sanitation. `sanitize-template.sh` remains in the
repository only as historical/defensive tooling for the earlier booted-template
design; it is not part of current Phase 3.

## Phase 3 prerequisites

Before `create-template.sh --apply`:

1. `cuda-katra` is active on the accepted 256 GiB SN5100 allocation.
2. VMID 9320 and template name `tpl-compute-ubuntu2604-20260808` are unused.
3. `vmbr0` is operational.
4. The accepted SN5100 partition boundary and host VFIO state are unchanged.
5. The concrete source/profile is `proxmox/hv-katra-template.yaml`.

Run:

```bash
proxmox/create-template.sh \
  --profile proxmox/hv-katra-template.yaml \
  --dry-run

proxmox/create-template.sh \
  --profile proxmox/hv-katra-template.yaml \
  --apply
```

The script verifies the accepted Canonical image SHA-256, imports it onto
`cuda-katra`, creates EFI and cloud-init disks on the same storage, never starts VM
9320, converts it directly to a Proxmox template, and verifies the final shape.
