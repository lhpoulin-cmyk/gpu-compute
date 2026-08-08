# Security Boundary

## Guest boundary

Guest logic runs inside VM 320. It may:
- Install and configure Ubuntu packages.
- Manage Ollama, llama.cpp, and CUDA toolkit packages.
- Read and write within `/srv/cuda-compute`, `/mnt/models`, and
  `/var/log/cuda-compute`.
- Start and stop the Ollama systemd service.
- Observe GPU state via `nvidia-smi` and CUDA runtime queries.

Guest logic must not:
- Modify host GPU passthrough, VFIO binding, or IOMMU configuration.
- Access or modify the SN5100 partition table.
- Access, enumerate, or modify other VMs on hv-katra.
- Contact hv-katra's Proxmox API or SSH interface.
- Write to NFS shares or arpa storage paths.
- Execute `qm`, `pvesh`, `pvesm`, or other Proxmox CLI tools.

## Network exposure

The Ollama HTTP API (`127.0.0.1:11434`) is bound to loopback only. It must not
be rebound to `0.0.0.0` or exposed to `vmbr0` without explicit operator review
and network-level access control. There is no production case for public model
serving from this appliance.

## Credentials and secrets

No credentials, API keys, or secrets are committed to this repository. Model
weights are not secrets but are large; they are not committed. Cloud-init
examples contain no real credentials; real cloud-init files are deployment
artifacts and live outside this repository.

## Agent authority

Agents operating inside VM 320 follow the guest runtime boundary in
`AGENTS.md`. They must not attempt to SSH to `hv-katra`, call the Proxmox API,
or self-elevate to make a host change. This guest restriction does not limit an
agent operating directly on `hv-katra` under an explicit, bounded
operator-authorized host play; that control-plane authority is defined in
`AGENTS.md`.
