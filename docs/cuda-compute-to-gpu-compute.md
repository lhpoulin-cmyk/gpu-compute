# cuda-compute to gpu-compute

`cuda-compute` is the former name of this project. `gpu-compute` is the current
authoritative project identity and `/srv/gpu-compute` is the canonical appliance
source path after the deployment migration.

`/srv/cuda-compute` remains a preserved legacy source/evidence tree while
consumers migrate. Historical evidence is not rewritten merely to remove the
former name. The VM hostname `cuda-compute-katra` and existing compatibility
locations such as `/var/lib/cuda-compute` and `/usr/local/share/cuda-compute`
remain unchanged until separately authorized runtime-state migrations.

This document separates current project identity from hostname and historical
deployment identity; it does not authorize retirement of the legacy tree.
