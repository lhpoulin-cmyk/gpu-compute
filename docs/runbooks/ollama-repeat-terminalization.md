# Ollama v0.32.0 repeat-limit terminalization

The Katra runtime pins upstream Ollama v0.32.0 commit
`f1a0ffd6219b5ef82aee77254f895b383efb5486` and carries one bounded local
patch. The patch changes reporting only: the existing `tokenRepeat > 30`
guard still stops generation at the same point, but it now emits one terminal
completion with `done_reason=repeat_limit` instead of returning a nil
`ctx.Err()` and closing the API response nonterminally.

The patch is
`patches/ollama/v0.32.0-repeat-limit-terminalization.patch`. Its expected
SHA-256 is
`4cc8126f2c30401875714fd7974d21389105cf4b018094f5cb3be24f1a803299`.
It includes model-free completion and streaming/non-streaming API regression
tests. It also proves genuine context cancellation remains an error and records
the separate, unchanged clean-SSE-without-stop behavior.

## Reproducible build

Use an exact clean checkout at the pinned commit and distro Go 1.26.0. The
server-only Go rebuild deliberately reuses the unmodified native runtime
payload shipped by the pinned v0.32.0 release; no llama.cpp, CUDA library, model
artifact, or generation setting changes.

```text
bin/build-patched-ollama \
  --source /bounded/ollama-v0.32.0 \
  --output /bounded/ollama-0.32.0-helix-repeatlimit.1
```

The script verifies source and patch identities, applies the patch, formats the
four touched Go files, runs the focused upstream tests, and builds with
`-buildvcs=false`, `-trimpath`, release mode, and version
`0.32.0+helix.repeatlimit.1`.

## Deployment and rollback

Before deployment, record the active binary hash, build ID, service state, and
native-payload hashes. Stop the service, install the published patched binary
as `/usr/bin/ollama`, then start the service and verify its version, binary
hash, loopback listener, and ordinary machine-response behavior. Retain the
upstream binary as a root-owned rollback artifact with its original hash.

Rollback is a separate operator action: stop the service, restore the retained
upstream binary, verify SHA-256, and start the service. Never mix a rebuilt
native payload with this Go-only patch.
