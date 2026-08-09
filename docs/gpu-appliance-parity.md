# gpu-compute / gpu-encode appliance parity

Sibling reference: `gpu-encode` checkpoint
`64c70e5543db996ea63bc03292c2c8f97ee9ce21`.

| Shared concept | gpu-compute path | gpu-encode path | Intentional difference |
| --- | --- | --- | --- |
| Hardware profiles | `profiles/` | `profiles/` | Compute accepts CUDA/inference hardware; encode accepts media accelerators. |
| Template construction | `proxmox/create-template.sh` | `proxmox/create-template.sh` | Both use a hardware-neutral cloud-image template. |
| Instance deployment | `proxmox/deploy-instance.sh` | `proxmox/deploy-instance.sh` | Compute attaches its GPU and model disk contract; encode attaches its workload-specific accelerator/storage. |
| Networking | Proxmox cloud-init and MAC-bound guest netplan | Proxmox cloud-init and MAC-bound guest netplan | Neither requires cosmetic interface renaming. |
| Root and durable data | Disposable root; `/mnt/models`, `LABEL=cuda-models` | Disposable root; media source/work/output/archive roots | Workload data differs, logical mount contracts do not. |
| Package safety | `bootstrap/packages.sh`, `bootstrap/stack-nvidia-modern.sh` | `bootstrap/packages.sh` | Both simulate bounded transactions and reject removals; package sets remain accelerator-specific. |
| Acceptance | CUDA, llama.cpp, Ollama GPU residency, no CPU fallback | VA-API/QSV/FFmpeg output validation, no software fallback | Each validates its own execution path. |
| Telemetry | `telemetry/capture-case-session.sh` | `telemetry/capture-session.sh` | Shared bounded session artifacts; collector fields are vendor/workload specific. |
| Evidence | `evidence/`, optional SOPS+age promotion | `evidence/`, optional SOPS+age promotion | Raw telemetry, models, and generated application outputs stay outside Git. |
| Backing storage | `/mnt/models` label contract | Logical media-root contracts | Either appliance may later use LVM-thin, ZFS, Ceph RBD, or another approved backend without changing application semantics. |

`cuda-compute` is the historical NVIDIA/CUDA implementation that established
the first accepted gpu-compute appliance. Existing VM, hostname, storage, run,
and evidence identifiers remain provenance and are not renamed by this parity
work.
