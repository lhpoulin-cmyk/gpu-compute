# Upstream packet: repeat guard closes generation without a terminal event

Affected source: Ollama v0.32.0,
`f1a0ffd6219b5ef82aee77254f895b383efb5486`, `llm/llama_server.go`.

When more than 30 equal trimmed token fragments arrive, `Completion` logs
`prediction aborted, token repeat limit reached` and returns `ctx.Err()`. With
a healthy request context, `ctx.Err()` is nil. The response channel therefore
closes without a terminal callback. `/api/generate` returns HTTP 200 with
`done:false` and clean EOF in both streaming and non-streaming modes.

The model-independent reproducer supplies 32 identical nonterminal SSE content
events to `llamaServerRunner.Completion`. Before the patch it receives content
callbacks and no terminal callback. The patch preserves the threshold and
generated content, stops at the same triggering event, and emits exactly one
terminal callback with `done_reason=repeat_limit`. Route tests prove streaming
gets a final terminal event and non-streaming gets one aggregated terminal
object retaining the partial content. A cancellation regression proves genuine
`context.Canceled` remains an error.

The minimal patch and tests are in
`patches/ollama/v0.32.0-repeat-limit-terminalization.patch`. This packet is
prepared for the existing upstream issue #8786 but has not been submitted.
