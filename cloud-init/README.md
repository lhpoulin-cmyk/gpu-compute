# Cloud-init examples

These examples show the structure of cloud-init files for VM 320. Real files
contain actual credentials and live outside this repository.

Do not commit populated user-data, vendor-data, or network-config files here.

The deploy script stages them to the Proxmox snippets storage and references
them via `--cicustom`. After first boot, cloud-init runs once; subsequent
boots skip it. Cloud-init does not install the NVIDIA driver or run the
appliance bootstrap; those are explicit post-boot operator steps.
