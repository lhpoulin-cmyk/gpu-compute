# Hardware Profiles

Hardware profiles describe portable compute-stack requirements and expectations
for a supported GPU class. Private deployment profiles supply host-specific
facts such as Proxmox node, bridges, resource mappings, storage and identity.

## nvidia-rtx5070ti

`config/profiles/nvidia-rtx5070ti/profile.yaml`

- GPU: NVIDIA GeForce RTX 5070 Ti (GB203 Blackwell)
- Compute-function PCI ID: `10de:2c05`
- Companion HDA PCI ID: `10de:22e9`
- Compute capability: **12.0** (`sm_120`)
- VRAM: 16 GiB
- Guest kernel driver: `nvidia`, installed from NVIDIA's `nvidia-open` package
- CUDA toolkit: pinned **13.3** (`cuda-toolkit-13-3`)
- Acceptance minimum driver: **610.43.02**
- Production stack: Ollama 0.32.0 and llama.cpp b10173 with CUDA enabled
- Experimental path: Vulkan compute
- Status: not accepted until VM 320 completes the acceptance suite

The exact GPU identity and compute capability are verified at runtime. Profile
values are expectations, not evidence.

## generic

`config/profiles/generic/profile.yaml` is a placeholder for future NVIDIA
profiles. Deployment-required fields must be supplied before use.

## Adding a profile

1. Copy the generic profile.
2. Record expected GPU identity, driver policy, CUDA branch, compute capability,
   device nodes, and explicit software pins.
3. Add profile-appropriate tests.
4. Accept only after observed hardware and workload evidence match the profile.
