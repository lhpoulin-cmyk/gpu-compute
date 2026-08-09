# Deployment

## Prerequisites

Before deploying VM 320, complete these host-side steps on `hv-katra`:

1. **Blacklist nouveau**: ensure `nouveau` is blacklisted in
   `/etc/modprobe.d/blacklist-nouveau.conf` and initrd is updated. Reboot to
   confirm `lsmod | grep nouveau` returns empty.

2. **Provision dedicated CUDA Proxmox storage**: use `proxmox/nvme-provision.sh` with the observed by-id `nvme-Sandisk_Optimus_5100_1TB_26100U800434`, expected serial `26100U800434`, and a 256 GiB allocation. The script creates an LVM PV/VG/thin pool and registers Proxmox storage `cuda-katra`. See `docs/runbooks/nvme-provisioning.md`.

3. **Prepare GPU passthrough and the logical resource mapping**: bind the observed
   RTX 5070 Ti functions `01:00.0` (`10de:2c05`) and `01:00.1` (`10de:22e9`)
   to VFIO because they share IOMMU group 1. Under Datacenter → Resource
   Mappings → PCI Devices, create exclusive mapping `gpu-compute-rtx5070ti`
   for the compute function `01:00.0`. The companion audio function remains
   bound/parked unless explicitly needed by the guest.

4. **Build or import template VM 9320**: follow `docs/template-build.md` to
   build the Ubuntu 26.04 template without GPU, NVMe passthrough, or identity.

## Deployment flow

A real deployment profile supplies release/template, target VM identity and
node, CPU/memory, both bridges, logical GPU resource mapping, dedicated Proxmox storage ID,
hardware profile, and model virtual-disk size. Generic source never contains the
physical PCI address or disk by-id path. Define mappings in Proxmox under
Datacenter → Resource Mappings → PCI Devices, for example
`gpu-compute-rtx5070ti`.

Run `proxmox/deploy-instance.sh --dry-run --profile PRIVATE.yaml`; after review,
run with `--apply`. Supported controls are `--dry-run`, `--profile`,
`--no-start`, and `--skip-gpu`. The script clones only the configured generic
template (9320), configures identity/resources/cloud-init, attaches the logical
GPU mapping and a second virtual disk from `cuda-katra`, starts when allowed, and prints guest
bootstrap/finalization steps. It validates unresolved placeholders,
template/target/name/storage/resource mapping/cloud-init inputs, current
`vmbr0`/`vmbr1` bridge state, `vmbr1` MTU >= 9000, and exclusive mapping use
before mutation. The current evidence says `vmbr1` is UP/LOWER_UP; a stale
boot-journal `enp2s0` error is not treated as proof that the bridge is down.

Real profiles should live separately, for example
`helix-arpa-infra/nodes/hv-katra/cuda-compute-katra.yaml`. Do not commit them
here. Acceptance, not cloning, promotes the instance. Rollback stops and
destroys only the failed new clone after evidence capture; it does not change
the template or VM 320.

## Post-deployment guest steps

After the VM first boots:

```bash
# On the guest (cuda-compute-katra):
cd /srv/cuda-compute
bootstrap/install.sh --profile config/profiles/nvidia-rtx5070ti/profile.yaml --dry-run
# Review output, then:
bootstrap/install.sh --profile config/profiles/nvidia-rtx5070ti/profile.yaml --apply
# Reboot after NVIDIA driver installation:
sudo reboot
# After reboot, run acceptance:
bin/doctor
tests/smoke/appliance
tests/smoke/cuda-nvidia
tests/acceptance/appliance
```
