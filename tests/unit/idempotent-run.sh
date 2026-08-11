#!/usr/bin/env bash
set -Eeuo pipefail
source_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
work=$(mktemp -d); trap 'rm -rf -- "$work"' EXIT
mkdir -p "$work/appliance/bin" "$work/appliance/config" "$work/appliance/evidence" "$work/fake"
cp "$source_root/bin/run" "$source_root/bin/run-status" "$work/appliance/bin/"
touch "$work/appliance/config/active-hardware-profile.yaml"
cat > "$work/appliance/bin/model-execution-policy" <<'SH'
#!/usr/bin/env bash
if [[ $1 == --evaluate-ps ]]; then printf 'manifest_digest: d\nquantization: Q\nexecution_policy: p\npolicy_result: GPU_PRIMARY_PARTIAL_OFFLOAD\nobserved_cpu_percent: 20\nobserved_gpu_percent: 80\nobserved_processor: 20%%/80%% CPU/GPU\n'; fi
SH
cat > "$work/appliance/bin/ollama-machine-response" <<'SH'
#!/usr/bin/env bash
printf 'launch\n' >> "${FAKE_LAUNCHES:?}"
[[ -z ${FAKE_DELAY:-} ]] || sleep "$FAKE_DELAY"
[[ -z ${FAKE_FAIL:-} ]] || exit 1
while [[ $# -gt 0 ]]; do
  case "$1" in
    --output) printf 'response' > "$2"; shift 2 ;;
    --metadata-output)
      printf '%s\n' '{"done":true,"done_reason":"stop","done_reason_present":true,"eval_count":1,"eval_duration":1,"evidence_contract":"OLLAMA_RESPONSE_META_V1","load_duration":1,"model":"model","prompt_eval_count":1,"prompt_eval_duration":1,"total_duration":1}' > "$2"
      shift 2 ;;
    *) shift ;;
  esac
done
SH
for command in findmnt systemctl; do cat > "$work/fake/$command" <<'SH'
#!/usr/bin/env bash
exit 0
SH
done
cat > "$work/fake/df" <<'SH'
#!/usr/bin/env bash
case "$*" in *avail*) printf 'Avail\n100G\n' ;; *) printf 'Use%%\n10%%\n' ;; esac
SH
cat > "$work/fake/ollama" <<'SH'
#!/usr/bin/env bash
printf 'NAME ID SIZE PROCESSOR CONTEXT UNTIL\nmodel d 1 20%%/80%% CPU/GPU 4096 x\n'
SH
chmod +x "$work/appliance/bin/"* "$work/fake/"*
id=alpha-test-family-C03-t0001-abcdef
FAKE_LAUNCHES="$work/launches" PATH="$work/fake:$PATH" "$work/appliance/bin/run" --invocation-id "$id" --model model --prompt prompt --execution-policy p >/dev/null
FAKE_LAUNCHES="$work/launches" PATH="$work/fake:$PATH" "$work/appliance/bin/run" --invocation-id "$id" --model model --prompt prompt --execution-policy p >/dev/null
[[ $(wc -l < "$work/launches") == 1 ]]
! PATH="$work/fake:$PATH" "$work/appliance/bin/run" --invocation-id "$id" --model model --prompt changed --execution-policy p >/dev/null 2>&1
status=$("$work/appliance/bin/run-status" --invocation-id "$id")
grep -q 'state: SUCCEEDED' <<< "$status"
grep -q 'completion_meta_available: yes' <<< "$status"
grep -q '^completion_meta_sha256: ' <<< "$status"
job=$(cat "$work/appliance/evidence/invocations/$id/job-id")
cmp "$work/appliance/evidence/invocations/$id/ollama-response-meta.json" "$work/appliance/evidence/$job/ollama-response-meta.json"
grep -q '^response_evidence_contract: OLLAMA_RESPONSE_META_V1$' "$work/appliance/evidence/$job/meta.yaml"
grep -q '^completion_meta_sha256: ' "$work/appliance/evidence/$job/meta.yaml"
status=$("$work/appliance/bin/run-status" --invocation-id alpha-test-family-C03-t0002-abcdef)
grep -q 'state: NOT_STARTED' <<< "$status"
concurrent=alpha-test-family-C03-t0003-abcdef
FAKE_LAUNCHES="$work/launches" FAKE_DELAY=1 PATH="$work/fake:$PATH" "$work/appliance/bin/run" --invocation-id "$concurrent" --model model --prompt prompt --execution-policy p >/dev/null & first=$!
FAKE_LAUNCHES="$work/launches" FAKE_DELAY=1 PATH="$work/fake:$PATH" "$work/appliance/bin/run" --invocation-id "$concurrent" --model model --prompt prompt --execution-policy p >/dev/null 2>&1 & second=$!
wait "$first"; wait "$second" || true
[[ $(wc -l < "$work/launches") == 2 ]]
failed=alpha-test-family-C03-t0004-abcdef
! FAKE_LAUNCHES="$work/launches" FAKE_FAIL=1 PATH="$work/fake:$PATH" "$work/appliance/bin/run" --invocation-id "$failed" --model model --prompt prompt --execution-policy p >/dev/null 2>&1
! FAKE_LAUNCHES="$work/launches" PATH="$work/fake:$PATH" "$work/appliance/bin/run" --invocation-id "$failed" --model model --prompt prompt --execution-policy p >/dev/null 2>&1
[[ $(wc -l < "$work/launches") == 3 ]]
printf 'PASS idempotent-run\n'
