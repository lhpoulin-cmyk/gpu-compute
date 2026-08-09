# Review notes — 2026-08-08

The branch `work/rebuild-phase3-on-proven-pattern-20260808` intentionally replaces
the blocked Phase 3A provenance experiment with the appliance-construction pattern
already proven by the B70 encode work.

Key decisions:

- Phase 1 storage and Phase 2 VFIO remain accepted.
- VM 9320 is an unbooted Canonical Ubuntu 26.04 cloud-image template.
- Phase 3 contains no guest bootstrap, CUDA/ROCm install, or sanitation.
- The RTX 5070 Ti is the immediate post-template reference deployment.
- RX 9070 XT is a modern Ubuntu 26.04 design-stage profile for later local testing.
- Arc Pro B70 work is deferred until a B70 is local to the test platform.
- Quadro P6000 is legacy compatibility using a separate Ubuntu 24.04 root when tested.
- The durable 160 GiB model/data disk is preserved across explicitly reviewed root/GPU swaps.

The immediate acceptance target is only a correct VM 9320 Proxmox template on
`cuda-katra`.
