#!/usr/bin/env bash
set -Eeuo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
source "$root/bin/model-execution-policy"

failures=0
expect() { local expected=$1 actual=$2 label=$3; if [[ $actual == "$expected" ]]; then printf '[PASS] %s\n' "$label"; else printf '[FAIL] %s: expected %s, got %s\n' "$label" "$expected" "$actual" >&2; failures=$((failures + 1)); fi; }
expect_parse_failure() { local raw=$1 label=$2; if parse_processor_split "$raw" >/dev/null; then printf '[FAIL] %s: unexpectedly parsed\n' "$label" >&2; failures=$((failures + 1)); else printf '[PASS] %s\n' "$label"; fi; }

expect GPU_ONLY "$(classify_processor_split GPU_ONLY 100 0 0 100)" '100% GPU is GPU_ONLY'
expect GPU_ONLY "$(classify_processor_split GPU_ONLY 100 0 0 100)" '0%/100% CPU/GPU equivalent is GPU_ONLY'
expect GPU_PRIMARY_PARTIAL_OFFLOAD "$(classify_processor_split GPU_PRIMARY_PARTIAL_OFFLOAD 80 20 20 80)" '20%/80% Qwen profile accepted'
expect GPU_PRIMARY_PARTIAL_OFFLOAD "$(classify_processor_split GPU_PRIMARY_PARTIAL_OFFLOAD 80 20 19 81)" '19%/81% Qwen profile accepted'
expect RUNTIME_PROFILE_VIOLATION "$(classify_processor_split GPU_PRIMARY_PARTIAL_OFFLOAD 80 20 21 79 || true)" '21%/79% violates Qwen profile'
expect GPU_PRIMARY_PARTIAL_OFFLOAD "$(classify_processor_split GPU_PRIMARY_PARTIAL_OFFLOAD 88 12 12 88)" '12%/88% Devstral profile accepted'
expect RUNTIME_PROFILE_VIOLATION "$(classify_processor_split GPU_PRIMARY_PARTIAL_OFFLOAD 88 12 13 87 || true)" '13%/87% violates Devstral profile'
expect GPU_PRIMARY_PARTIAL_OFFLOAD "$(classify_processor_split GPU_PRIMARY_PARTIAL_OFFLOAD 51 49 49 51)" '49%/51% is GPU-primary for hypothetical profile'
expect CPU_FALLBACK "$(classify_processor_split GPU_PRIMARY_PARTIAL_OFFLOAD 50 50 50 50 || true)" '50%/50% fails global floor'
expect CPU_FALLBACK "$(classify_processor_split GPU_PRIMARY_PARTIAL_OFFLOAD 51 49 60 40 || true)" 'GPU minority is CPU_FALLBACK'
expect CPU_FALLBACK "$(classify_processor_split GPU_PRIMARY_PARTIAL_OFFLOAD 51 49 100 0 || true)" 'CPU only is CPU_FALLBACK'
expect_parse_failure 'GPU' 'GPU word without parseable split fails closed'
expect_parse_failure '' 'no active model processor text fails closed'
expect '20 80' "$(parse_processor_split '20%/80% CPU/GPU')" 'documented CPU/GPU split parses'
expect '0 100' "$(parse_processor_split '100% GPU')" 'documented GPU-only split parses'

fixture=$(mktemp)
trap 'rm -f "$fixture"' EXIT
printf '# header\nprofile\tqwen3-coder:30b\texact\tQ4_K_M\tcuda-compute-katra\thv-katra\tNVIDIA GeForce RTX 5070 Ti\tGPU_PRIMARY_PARTIAL_OFFLOAD\t80\t20\t14890\tACCEPTED\n' > "$fixture"
if find_profile "$fixture" qwen3-coder:30b exact cuda-compute-katra 'NVIDIA GeForce RTX 5070 Ti' >/dev/null; then printf '[PASS] exact digest profile applies\n'; else printf '[FAIL] exact digest profile applies\n' >&2; failures=$((failures + 1)); fi
if find_profile "$fixture" qwen3-coder:30b different cuda-compute-katra 'NVIDIA GeForce RTX 5070 Ti' >/dev/null; then printf '[FAIL] digest mismatch incorrectly applies profile\n' >&2; failures=$((failures + 1)); else printf '[PASS] digest mismatch leaves profile stale\n'; fi

printf 'profile\tdevstral-small-2:24b-instruct-2512-q4_K_M\tdevstral-exact\tQ4_K_M\tcuda-compute-katra\thv-katra\tNVIDIA GeForce RTX 5070 Ti\tGPU_PRIMARY_PARTIAL_OFFLOAD\t88\t12\t14648\tACCEPTED\n' >> "$fixture"
if find_profile "$fixture" devstral-small-2:24b-instruct-2512-q4_K_M devstral-exact cuda-compute-katra 'NVIDIA GeForce RTX 5070 Ti' >/dev/null; then printf '[PASS] exact Devstral profile applies\n'; else printf '[FAIL] exact Devstral profile applies\n' >&2; failures=$((failures + 1)); fi
if find_profile "$fixture" devstral-small-2:24b-instruct-2512-q4_K_M different cuda-compute-katra 'NVIDIA GeForce RTX 5070 Ti' >/dev/null; then printf '[FAIL] Devstral digest mismatch incorrectly applies profile\n' >&2; failures=$((failures + 1)); else printf '[PASS] Devstral digest mismatch leaves profile stale\n'; fi

printf 'profile\tqwen2.5-coder:14b-instruct-q4_K_M\tqwen25-exact\tQ4_K_M\tcuda-compute-katra\thv-katra\tNVIDIA GeForce RTX 5070 Ti\tGPU_ONLY\t100\t0\t9304\tACCEPTED\n' >> "$fixture"
if find_profile "$fixture" qwen2.5-coder:14b-instruct-q4_K_M qwen25-exact cuda-compute-katra 'NVIDIA GeForce RTX 5070 Ti' >/dev/null; then printf '[PASS] exact Qwen2.5-Coder profile applies\n'; else printf '[FAIL] exact Qwen2.5-Coder profile applies\n' >&2; failures=$((failures + 1)); fi
if find_profile "$fixture" qwen2.5-coder:14b-instruct-q4_K_M different cuda-compute-katra 'NVIDIA GeForce RTX 5070 Ti' >/dev/null; then printf '[FAIL] Qwen2.5-Coder digest mismatch incorrectly applies profile\n' >&2; failures=$((failures + 1)); else printf '[PASS] Qwen2.5-Coder digest mismatch leaves profile stale\n'; fi

printf 'profile\tqwen2.5-coder:32b-instruct-q4_K_M\tqwen25-32b-exact\tQ4_K_M\tcuda-compute-katra\thv-katra\tNVIDIA GeForce RTX 5070 Ti\tGPU_PRIMARY_PARTIAL_OFFLOAD\t71\t29\t14634\tACCEPTED\n' >> "$fixture"
if find_profile "$fixture" qwen2.5-coder:32b-instruct-q4_K_M qwen25-32b-exact cuda-compute-katra 'NVIDIA GeForce RTX 5070 Ti' >/dev/null; then printf '[PASS] exact Qwen2.5-Coder 32B profile applies\n'; else printf '[FAIL] exact Qwen2.5-Coder 32B profile applies\n' >&2; failures=$((failures + 1)); fi
if find_profile "$fixture" qwen2.5-coder:32b-instruct-q4_K_M different cuda-compute-katra 'NVIDIA GeForce RTX 5070 Ti' >/dev/null; then printf '[FAIL] Qwen2.5-Coder 32B digest mismatch incorrectly applies profile\n' >&2; failures=$((failures + 1)); else printf '[PASS] Qwen2.5-Coder 32B digest mismatch leaves profile stale\n'; fi

[[ $failures -eq 0 ]] || exit 1
echo 'model-execution-policy: PASS'
