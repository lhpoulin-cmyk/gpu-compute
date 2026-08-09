# Runbook: Incident Recovery

## GPU not visible in guest

**Symptoms**: `lspci` shows no NVIDIA device; `/dev/nvidia0` absent;
`nvidia-smi` fails.

**Check host**:
```bash
# On hv-katra:
lspci -nnk | grep -A3 NVIDIA
qm config 320 | grep hostpci
pvesh get /cluster/mapping/pci
```

**Check VFIO**:
```bash
lsmod | grep vfio
cat /proc/vfio-pci/id
```

If `nouveau` is loaded: the blacklist did not apply. Reboot the host after
verifying `/etc/modprobe.d/blacklist-nouveau.conf` and re-running
`update-initramfs -u`.

If the resource mapping is missing or incorrect: recreate under
Datacenter → Resource Mappings → PCI Devices.

Stop and do not attempt to repair VFIO or IOMMU from inside the guest.

## Ollama service not starting

```bash
journalctl -u ollama --no-pager -n 50
systemctl status ollama
```

Check that `/mnt/models` is mounted before the service starts. If the mount
is absent, Ollama will fall back to writing under `/var`:

```bash
findmnt -M /mnt/models
```

If unmounted, mount manually then restart:
```bash
mount /mnt/models
systemctl restart ollama
```

Check the systemd unit override is present:
```bash
cat /etc/systemd/system/ollama.service.d/override.conf
```

## CUDA library errors

```bash
ldconfig -p | grep -E 'libcuda|libnvidia|libcudart'
ls -la /dev/nvidia*
```

If device nodes are absent but the GPU is visible in `lspci`:
```bash
nvidia-smi  # this re-creates device nodes on some versions
modprobe nvidia-uvm
```

If `libcuda.so` is absent or broken: reinstall the driver package matching
the installed version.

## NVMe mount absent

```bash
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT
cat /etc/fstab | grep models
findmnt -M /mnt/models
```

If the block device is absent: check `qm config 320 | grep scsi1` on the
host. The partition may have been detached.

If the device is present but unmounted: `mount /mnt/models`. Investigate why
the automatic mount failed before rebooting.

## Rollback procedure

To destroy and recreate VM 320 from template 9320:

```bash
# On hv-katra:
qm stop 320
qm destroy 320 --purge
# Re-run deployment:
proxmox/deploy-instance.sh --profile PRIVATE.yaml --apply
```

The SN5100 NVMe partition (model storage) is preserved through a VM destroy;
the model library does not need to be re-downloaded. Re-attach `scsi1` after
the new clone is created.
