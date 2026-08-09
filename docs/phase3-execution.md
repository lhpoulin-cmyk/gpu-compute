# Phase 3 execution — VM 9320

This is the bounded execution surface for the current Phase 3.

1. Fetch the review branch and validate the repository:

   ```bash
   git fetch origin
   git checkout work/rebuild-phase3-on-proven-pattern-20260808
   git pull --ff-only
   bash tests/unit/template-contract.sh
   find . -type f -name '*.sh' -print0 | xargs -0 -n1 bash -n
   git diff --check master...HEAD
   ```

2. Review the rendered host operation:

   ```bash
   proxmox/create-template.sh \
     --profile proxmox/hv-katra-template.yaml \
     --dry-run
   ```

3. If live preflight still matches the accepted host state, apply:

   ```bash
   proxmox/create-template.sh \
     --profile proxmox/hv-katra-template.yaml \
     --apply
   ```

4. Verify `qm config 9320`, `pvesm status`, SN5100 partition boundary, VFIO state,
   host bridges, existing guests, and before/after host telemetry.

5. Stop. Do not create VM 320 in Phase 3.

VM 9320 must remain an unbooted Ubuntu 26.04 cloud-image template with all VM disks
on `cuda-katra`, one `vmbr0` NIC, no GPU, and no model disk.
