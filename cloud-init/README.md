# Cloud-init

VM 320 uses standard Proxmox cloud-init fields. The deploy script configures:

- `ciuser`
- an operator SSH **public** key supplied at runtime
- static `ipconfig0` / `ipconfig1`
- DNS servers
- search domain
- `ciupgrade=0`

No populated cloud-init snippet files are committed or staged for the reference
hv-katra deployment. The runtime public-key file remains outside the repository.
Private keys, passwords, tokens, and GitHub credentials are never accepted as
cloud-init inputs.

The YAML files in this directory are illustrative historical examples only. They
are not inputs to `proxmox/deploy-instance.sh` and must not be treated as an
authoritative deployment profile.

Cloud-init establishes the first-boot identity and operator access only. It does
not format the model disk, transfer the private repository source, install the GPU
software stack, or run appliance acceptance. Those remain explicit post-boot gates.
