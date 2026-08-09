#!/usr/bin/env bash
set -Eeuo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
root=$(cd -- "$script_dir/.." && pwd)
profile= operator=
dry_run=false
template_mode=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile)       profile=${2:?missing profile}; shift 2 ;;
    --operator)      operator=${2:?missing operator}; shift 2 ;;
    --dry-run)       dry_run=true; shift ;;
    --template-mode) template_mode=true; shift ;;
    *) echo "usage: install.sh --profile FILE [--operator USER] [--dry-run] [--template-mode]" >&2; exit 64 ;;
  esac
done

[[ -n "$profile" ]] || { echo "--profile is required" >&2; exit 64; }

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
  echo "would verify commands and run profile-appropriate tests after GPU attachment"
else
  for command in doctor probe run validate-output collect-evidence; do
    [[ -x "$root/bin/$command" ]] || { echo "missing command: $command" >&2; exit 69; }
  done
  $template_mode || "$root/tests/smoke/appliance"
fi
