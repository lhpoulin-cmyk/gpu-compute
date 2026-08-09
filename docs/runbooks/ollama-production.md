# Runbook: Ollama Production Inference

**Guest**: `cuda-compute-katra` (VM 320)
**Pinned Ollama**: 0.32.0
**Model storage**: `/mnt/models/library`

The service override must keep the API loopback-only and all model bytes off the
root filesystem:

```ini
[Service]
Environment="OLLAMA_MODELS=/mnt/models/library"
Environment="OLLAMA_HOST=127.0.0.1:11434"
Environment="CUDA_VISIBLE_DEVICES=0"
```

After editing: `systemctl daemon-reload && systemctl restart ollama`.

## Smoke model

```bash
ollama pull llama3.2:1b
ollama run llama3.2:1b 'Return VERIFIED.'
ollama ps
```

`ollama ps` must report GPU residency before output can be accepted.

## Representative production-size example

A 70B Q4 model does not fit the 16 GiB GPU-only policy and must not be the
reference production example. Use a model that fits VRAM with headroom; for
example, after explicit model selection:

```bash
ollama pull qwen3:8b
bin/run \
  --model qwen3:8b \
  --prompt 'Summarize CUDA unified memory.' \
  --output /mnt/models/output/test-$(date +%s).txt
```

The exact representative model is an operator/model-policy decision, not a
hard-coded appliance invariant.

Never manually delete files from Ollama's `library/blobs` or `manifests` paths.
