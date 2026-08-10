# cuda-compute to gpu-compute

`cuda-compute` is the former name of this project. `gpu-compute` is the current
authoritative project identity and `/srv/gpu-compute` is the canonical appliance
source path after the deployment migration.

`/srv/cuda-compute` was the preserved legacy source/evidence tree during
consumer migration and was retired on 2026-08-10 after its classified runtime
state and evidence were hash-verified in
`/srv/gpu-compute-preservation-20260810T110900Z` and preserved under
`/srv/gpu-compute/evidence/legacy-cuda-compute/`. Historical evidence is not
rewritten merely to remove the former name. The VM hostname
`cuda-compute-katra` and existing compatibility locations such as
`/var/lib/cuda-compute` and `/usr/local/share/cuda-compute` remain unchanged
until separately authorized runtime-state migrations.

This document separates current project identity from hostname and historical
deployment identity; it records the completed retirement of the legacy tree.
