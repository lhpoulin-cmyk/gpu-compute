# Runbook: RTX 5070 Ti GPU Passthrough

**Host**: `hv-katra` (`192.168.10.21`)
**Compute function**: `0000:01:00.0` — `10de:2c05`
**Audio function**: `0000:01:00.1` — `10de:22e9`
**Observed IOMMU group**: 1 for both functions
**Guest**: VM 320

Host-side VFIO/IOMMU mutation may be performed only by an explicitly
operator-authorized host-side play on `hv-katra`. It is forbidden to ordinary
guest runtime logic. The commands below are an operator runbook and must be
reconciled with `hv-cp` before execution.

## Preconditions

Reconfirm immediately before mutation:

```bash
lspci -nnk -s 01:00.0
lspci -nnk -s 01:00.1
find /sys/kernel/iommu_groups/1/devices -maxdepth 1 -type l -printf '%f\n'
```

The assignable GPU endpoints are `01:00.0` and `01:00.1`, both in group 1. An IOMMU group is acceptable when it contains the complete target endpoint-function set plus its expected upstream PCI/PCIe bridge or root-port topology. Presence of that upstream bridge/root port is not itself a blocker and it must remain a normal host-owned bridge; do not bind or map it to VFIO. Stop if the group contains another endpoint device, another independently usable peripheral, an unexpected function, or topology that makes ownership/isolation ambiguous.

## Bind both functions to vfio-pci

The compute VM only needs the VGA/compute function, but the companion audio
function shares the IOMMU group. Account for it explicitly by binding **both**
functions to `vfio-pci`; the audio function may remain parked/unassigned if the
guest does not need HDMI/DP audio.

`/etc/modprobe.d/blacklist-nouveau.conf`:

```text
blacklist nouveau
options nouveau modeset=0
```

`/etc/modprobe.d/vfio.conf`:

```text
options vfio-pci ids=10de:2c05,10de:22e9
```

`/etc/initramfs-tools/modules` must contain these early-loaded modules (one per line):

```text
vfio
vfio_iommu_type1
vfio_pci
```

This host uses an initramfs and the modules must be present before PCI driver probing. Then update initramfs and reboot. After reboot:

```bash
lspci -nnk -s 01:00.0
lspci -nnk -s 01:00.1
```

Both functions must report `Kernel driver in use: vfio-pci` before VM 320 is
started.

## Proxmox resource mapping

Create the logical mapping `gpu-compute-rtx5070ti` for the compute function
`0000:01:00.0` on `hv-katra`, exclusive to this appliance. The companion audio
function remains bound to VFIO and unassigned unless the operator explicitly
decides VM 320 needs it.

Attach through `proxmox/attach-resource-mapping.sh`, or equivalent reviewed
Proxmox configuration.

## Guest verification

After the NVIDIA guest driver is installed and the VM reboots:

```bash
lspci -nnk | grep -A4 -i nvidia
nvidia-smi
llama-cli --list-devices
```

Expected guest state: RTX 5070 Ti, NVIDIA kernel driver, compute capability
12.0, and a llama.cpp `CUDA0` device.
