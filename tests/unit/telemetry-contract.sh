#!/usr/bin/env bash
set -Eeuo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
capture="$root/telemetry/capture-case-session.sh"
summary="$root/telemetry/summarize.py"
doc="$root/docs/thermal-telemetry.md"

for f in "$capture" "$summary" "$doc"; do
  [[ -r "$f" ]] || { echo "missing telemetry file: $f" >&2; exit 1; }
done

bash -n "$capture"
python3 -m py_compile "$summary"

grep -Fq '/sys/class/hwmon/hwmon' "$capture"
grep -Fq 'nvidia-smi --query-gpu=' "$capture"
grep -Fq 'temperature.gpu' "$capture"
grep -Fq 'power.draw' "$capture"
grep -Fq 'fan.speed' "$capture"
grep -Fq 'utilization.gpu' "$capture"
grep -Fq 'evidence/telemetry/' "$capture"
grep -Fq 'CPU package' "$summary"
grep -Fq 'GPU temp' "$summary"
grep -Fq 'raw telemetry' "$doc"

echo "telemetry-contract: PASS"
