#!/usr/bin/env bash
# Shared helpers for Proxmox host scripts.

# Proxmox administrative commands normally live in /usr/sbin. Some operator
# shells inherited on hv-katra omit sbin directories even when running as root.
# Normalize PATH for reviewed host tooling instead of treating that shell detail
# as an execution blocker.
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:${PATH:-}"

yaml_value() {
  local file=$1; shift
  local keys=("$@")
  local selector
  selector=$(printf '.%s' "${keys[@]}")
  python3 -c "
import sys
import yaml
with open('$file') as f:
    d = yaml.safe_load(f)
val = d
for k in ${selector@Q}.lstrip('.').split('.'):
    if not isinstance(val, dict) or k not in val:
        sys.exit(0)
    val = val[k]
if val is not None:
    print(str(val))
" 2>/dev/null
}

require_no_placeholders() {
  local file=$1
  if grep -qE 'deployment-required|PLACEHOLDER' "$file" 2>/dev/null; then
    echo "unresolved placeholders in profile: $file" >&2
    grep -nE 'deployment-required|PLACEHOLDER' "$file" >&2
    exit 65
  fi
}

shell_join() {
  local result=()
  for arg in "$@"; do
    if [[ "$arg" =~ [[:space:]] ]]; then
      result+=("'$arg'")
    else
      result+=("$arg")
    fi
  done
  printf '%s ' "${result[@]}"
}

require_proxmox_host() {
  command -v qm >/dev/null 2>&1 || { echo "qm not found; run on Proxmox host" >&2; exit 69; }
  command -v pvesh >/dev/null 2>&1 || { echo "pvesh not found" >&2; exit 69; }
  command -v pvesm >/dev/null 2>&1 || { echo "pvesm not found" >&2; exit 69; }
}
