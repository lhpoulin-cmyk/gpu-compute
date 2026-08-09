#!/usr/bin/env bash
set -Eeuo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
root=$(cd -- "$script_dir/.." && pwd)
profile= operator=
dry_run=false
template_mode=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile) profile=${2:?missing profile}; shift 2 ;;
    --operator) operator=${2:?missing operator}; shift 2 ;;
    --dry-run) dry_run=true; shift ;;
    --template-mode) template_mode=true; shift ;;
    *) echo "usage: install.sh --profile FILE [--operator USER] [--dry-run] [--template-mode]" >&2; exit 64 ;;
  esac
done

[[ -n "$profile" && -r "$profile" ]] || { echo "--profile FILE is required" >&2; exit 64; }
mode=--apply
$dry_run && mode=--dry-run

workspace_args=("$mode")
[[ -n "$operator" ]] && workspace_args+=(--operator "$operator")
$template_mode && workspace_args+=(--template-mode)
"$script_dir/workspace.sh" "${workspace_args[@]}"

package_args=(--profile "$profile" "$mode")
$template_mode && package_args+=(--template-mode)
"$script_dir/packages.sh" "${package_args[@]}"

profile_args=(--profile "$profile")
$dry_run && profile_args+=(--dry-run)
$template_mode && profile_args+=(--template-mode)
"$script_dir/install-profile.sh" "${profile_args[@]}"

if $dry_run; then
  echo "dry-run complete: no guest mutation"
  exit 0
fi

for command in doctor probe run validate-output collect-evidence; do
  [[ -x "$root/bin/$command" ]] || { echo "missing command: $command" >&2; exit 69; }
done

if $template_mode; then
  echo "template-mode bootstrap complete"
else
  echo "guest software installation complete"
  echo "DO NOT run GPU acceptance before reboot"
  echo "reboot, then run: bin/doctor && tests/smoke/appliance && tests/smoke/cuda-nvidia && tests/acceptance/appliance"
fi
