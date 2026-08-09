# Architecture

```text
VM 320 reference ──proves──> Git source of truth
                                  │
                                  ├──builds──> VM 9320 generic image
                                  │                 │
private deployment profile ──────┴──assigns────────┤
                                                    v
                          clone + GPU/network/identity + virtual model disk
                                                    │
                                     acceptance tests promote it
```

VM 320 stays attached to hv-katra and the RTX 5070 Ti because it is the
known-good operational reference and regression target. VM 9320 is separately
built without physical GPU, model disk, identity, credentials, or
model weights so clones do not inherit exclusive resources or secrets. Git is
authoritative because images are opaque artifacts; policy, scripts, profiles,
tests, and release provenance must remain reviewable and reproducible.

Hardware profiles describe portable compute-stack expectations. Private
deployment profiles assign a real Proxmox node, logical GPU resource mapping,
dedicated Proxmox storage, network, and identity. This separation prevents generic
code from encoding host PCI addresses or disk paths. A clone is only an
appliance after its observed hardware and inference behavior pass acceptance
and generate instance state.

## Compute stack layers

```text
NVIDIA RTX 5070 Ti (passthrough, PCIe)
    └── nvidia driver (kernel module)
          ├── CUDA 13.3 runtime (/dev/nvidia0, /dev/nvidia-uvm)
          │       ├── Ollama (model server, CUDA backend)
          │       │       └── /mnt/models/library  (SN5100 NVMe partition)
          │       └── llama.cpp (direct CUDA inference, llama-server / llama-cli)
          └── Vulkan (compute queue, experimental)
```

## Storage topology

```text
hv-katra: nvme0n1 (SN5100 1TB, serial 26100U800434)
    └── partition 1: 256 GiB (GPT/LVM)
          └── cuda-katra-vg / cuda-katra-thin
                ├── VM 9320 root: 32 GiB (temporary template, 90-day retention)
                ├── VM 320 root: 32 GiB
                └── VM 320 scsi1: 160 GiB
                      └── ext4 LABEL=cuda-models
                            └── /mnt/models
                                  ├── library/
                                  ├── work/
                                  ├── cache/
                                  └── output/
```

No VM disk is placed on Katra's boot ZFS pool. The host NVMe partition is never passed through to the guest.

## Job flow

```text
operator request → bin/run → validate model + request → CUDA inference
    → validate output → record evidence → OUTPUT_VALIDATED
```
