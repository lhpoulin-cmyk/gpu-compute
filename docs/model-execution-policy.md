# Model execution policy

`bin/run` does not infer acceptance from the word `GPU` in an Ollama status
line. Every controlled run names an execution policy and must match an exact,
accepted model-runtime profile in `config/model-runtime-profiles.tsv`.

## Classes

`GPU_ONLY` is exactly 0% CPU and 100% GPU. It is the preferred default.

`GPU_PRIMARY_PARTIAL_OFFLOAD` is an intentional, profile-bound mixed mode.
GPU residency must be proven, GPU must be strictly greater than CPU, and the
observed split must meet the profile's GPU minimum and CPU maximum.

`CPU_FALLBACK` includes CPU-only, GPU-minority, equal split, unproven GPU
residency, and unparseable processor evidence. It is rejected. A split that is
GPU-primary but outside a stricter accepted profile is a
`RUNTIME_PROFILE_VIOLATION`, also rejected.

## Profile binding and enforcement

Profiles bind tag, local manifest digest, quantization, appliance, host, and
accelerator. A tag update, different quantization, different appliance, or
different GPU does not inherit an older profile. Newly observed partial offload
remains `RUNTIME_PROFILE_UNCLASSIFIED` until `gpu-cp` accepts a profile.

`bin/run` accepts only `--execution-policy gpu-only` or
`--execution-policy gpu-primary-partial`; `--allow-cpu` is retired. The caller
cannot choose a permissive percentage. The runner validates the exact local
manifest, appliance/GPU identity, accepted profile, and a captured `ollama ps`
processor split after inference. It records the profile and policy result in
the operational evidence before output promotion.

Normal profiles and torture observations are distinct. A torture result cannot
broaden a normal accepted envelope.
