#!/usr/bin/env bash
set -Eeuo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$script_dir/profile-lib.sh"

profile=
ssh_public_key_file=
apply=false
no_start=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile) profile=${2:?}; shift 2 ;;
    --ssh-public-key-file) ssh_public_key_file=${2:?}; shift 2 ;;
    --dry-run) apply=false; shift ;;
    --apply) apply=true; shift ;;
    --no-start) no_start=true; shift ;;
    *)
      echo "usage: deploy-instance.sh --profile FILE --ssh-public-key-file FILE [--dry-run|--apply] [--no-start]" >&2
      exit 64
      ;;
  esac
done

[[ -r "$profile" ]] || { echo "profile required" >&2; exit 66; }
require_no_placeholders "$profile"
[[ -n "$ssh_public_key_file" && -r "$ssh_public_key_file" ]] || { echo "readable SSH public-key file required" >&2; exit 66; }
! grep -q 'PRIVATE KEY' "$ssh_public_key_file" || { echo "refusing private-key material" >&2; exit 65; }
grep -Eq '^(ssh-(ed25519|rsa)|ecdsa-sha2-|sk-ssh-|sk-ecdsa-)' "$ssh_public_key_file" \
  || { echo "SSH public-key file does not contain a recognized public key" >&2; exit 65; }

template=$(yaml_value "$profile" appliance template_vmid)
release=$(yaml_value "$profile" appliance release)
vmid=$(yaml_value "$profile" instance vmid)
name=$(yaml_value "$profile" instance name)
node=$(yaml_value "$profile" instance node)
cores=$(yaml_value "$profile" instance cores)
memory=$(yaml_value "$profile" instance memory_mb)
ciuser=$(yaml_value "$profile" instance cloud_init_user)
primary_bridge=$(yaml_value "$profile" virtualization primary_bridge)
secondary_bridge=$(yaml_value "$profile" virtualization secondary_bridge)
secondary_mtu=$(yaml_value "$profile" virtualization secondary_mtu)
primary_ip=$(yaml_value "$profile" network primary_ipv4)
primary_gw=$(yaml_value "$profile" network primary_gateway)
secondary_ip=$(yaml_value "$profile" network secondary_ipv4)
dns_servers=$(yaml_value "$profile" network dns_servers)
search_domain=$(yaml_value "$profile" network search_domain)
hardware_profile=$(yaml_value "$profile" gpu profile)
compute_fn=$(yaml_value "$profile" gpu host_compute_function)
audio_fn=$(yaml_value "$profile" gpu host_audio_function)
compute_id=$(yaml_value "$profile" gpu expected_compute_pci_id)
audio_id=$(yaml_value "$profile" gpu expected_audio_pci_id)
host_driver=$(yaml_value "$profile" gpu expected_host_driver)
storage=$(yaml_value "$profile" storage pve_storage_id)
root_size=$(yaml_value "$profile" storage root_disk_size_gib)
models_size=$(yaml_value "$profile" storage models_disk_size_gib)
models_label=$(yaml_value "$profile" storage models_label)
models_mount=$(yaml_value "$profile" storage models_mount)

required=(
  "$template" "$release" "$vmid" "$name" "$node" "$cores" "$memory" "$ciuser"
  "$primary_bridge" "$secondary_bridge" "$secondary_mtu" "$primary_ip" "$primary_gw"
  "$secondary_ip" "$dns_servers" "$search_domain" "$hardware_profile"
  "$compute_fn" "$audio_fn" "$compute_id" "$audio_id" "$host_driver" "$storage"
  "$root_size" "$models_size" "$models_label" "$models_mount"
)
for value in "${required[@]}"; do
  [[ -n "$value" ]] || { echo "deployment profile is incomplete: $profile" >&2; exit 65; }
done

[[ "$template" == 9320 && "$vmid" == 320 && "$node" == hv-katra ]] \
  || { echo "unexpected template/VMID/node contract" >&2; exit 65; }
[[ "$name" == cuda-compute-katra && "$storage" == cuda-katra ]] \
  || { echo "unexpected instance/storage contract" >&2; exit 65; }
[[ "$primary_bridge" == vmbr0 && "$secondary_bridge" == vmbr1 && "$secondary_mtu" == 9000 ]] \
  || { echo "unexpected bridge/MTU contract" >&2; exit 65; }
[[ "$hardware_profile" == nvidia-rtx5070ti ]] || { echo "unexpected GPU profile contract" >&2; exit 65; }
[[ "$root_size" == 32 && "$models_size" == 160 ]] \
  || { echo "unexpected disk-size contract" >&2; exit 65; }

commands=(
  "$(shell_join qm clone "$template" "$vmid" --name "$name" --full 1 --storage "$storage")"
  "$(shell_join qm set "$vmid" --cores "$cores" --memory "$memory" --net0 "virtio,bridge=$primary_bridge" --net1 "virtio,bridge=$secondary_bridge,mtu=$secondary_mtu")"
  "$(shell_join qm set "$vmid" --scsi1 "$storage:$models_size,discard=on,ssd=1,iothread=1")"
  "$(shell_join qm set "$vmid" --ciuser "$ciuser" --sshkeys "$ssh_public_key_file" --ciupgrade 0 --nameserver "$dns_servers" --searchdomain "$search_domain" --ipconfig0 "ip=$primary_ip,gw=$primary_gw" --ipconfig1 "ip=$secondary_ip")"
  "$(shell_join qm set "$vmid" --hostpci0 "$compute_fn,pcie=1,rombar=1")"
)
$no_start || commands+=("$(shell_join qm start "$vmid")")

echo "# Phase 4 candidate deployment"
printf '# release=%s hardware_profile=%s storage=%s model_disk=%sGiB label=%s mount=%s\n' \
  "$release" "$hardware_profile" "$storage" "$models_size" "$models_label" "$models_mount"
printf '%s\n' "${commands[@]}"
echo "# Post-boot work remains separate: verify guest/network/GPU, prepare /mnt/models, transfer source, install CUDA stack, reboot, accept."

$apply || exit 0
require_proxmox_host
command -v pvesm >/dev/null 2>&1 || { echo "pvesm not found" >&2; exit 69; }
command -v lspci >/dev/null 2>&1 || { echo "lspci not found" >&2; exit 69; }

[[ $(hostname -s) == "$node" ]] || { echo "wrong host: $(hostname -s), expected $node" >&2; exit 69; }

template_config=$(qm config "$template")
grep -Fx 'template: 1' <<<"$template_config" >/dev/null || { echo "VM $template is not a template" >&2; exit 69; }
grep -Eq '^scsi0: cuda-katra:.*size=32G' <<<"$template_config" || { echo "template root is not the accepted 32 GiB cuda-katra disk" >&2; exit 69; }
! grep -Eq '^hostpci|^scsi1:|bridge=vmbr1|local-zfs:|^scsi0: local:|^efidisk0: local:|^ide2: local:' <<<"$template_config" \
  || { echo "template no longer matches the accepted neutral contract" >&2; exit 69; }

qm status "$vmid" >/dev/null 2>&1 && { echo "target VMID already used: $vmid" >&2; exit 73; }
qm list | awk -v name="$name" 'NR>1 && $2 == name { found=1 } END { exit !found }' \
  && { echo "target name already used: $name" >&2; exit 73; }

pvesm status --storage "$storage" | awk 'NR==2 && $3=="active" {ok=1} END {exit !ok}' \
  || { echo "storage is not active: $storage" >&2; exit 69; }
available_kib=$(pvesm status --storage "$storage" | awk 'NR==2 {print $6}')
required_kib=$(( (root_size + models_size + 8) * 1024 * 1024 ))
[[ "$available_kib" =~ ^[0-9]+$ ]] || { echo "could not determine free space on $storage" >&2; exit 69; }
(( available_kib >= required_kib )) || { echo "insufficient free space on $storage for deployment reserve" >&2; exit 69; }

for bridge in "$primary_bridge" "$secondary_bridge"; do
  [[ -d "/sys/class/net/$bridge" ]] || { echo "bridge not found: $bridge" >&2; exit 69; }
  [[ "$(cat "/sys/class/net/$bridge/operstate" 2>/dev/null)" == up ]] || { echo "bridge is not operational: $bridge" >&2; exit 69; }
done
observed_secondary_mtu=$(cat "/sys/class/net/$secondary_bridge/mtu")
(( observed_secondary_mtu >= secondary_mtu )) || { echo "$secondary_bridge MTU $observed_secondary_mtu is below $secondary_mtu" >&2; exit 69; }

lspci -nns "$compute_fn" | grep -Fq "$compute_id" || { echo "compute function identity mismatch: $compute_fn" >&2; exit 69; }
lspci -nns "$audio_fn" | grep -Fq "$audio_id" || { echo "audio function identity mismatch: $audio_fn" >&2; exit 69; }
lspci -ks "$compute_fn" | grep -Fq "Kernel driver in use: $host_driver" || { echo "compute function is not bound to $host_driver" >&2; exit 69; }
lspci -ks "$audio_fn" | grep -Fq "Kernel driver in use: $host_driver" || { echo "audio function is not bound to $host_driver" >&2; exit 69; }

created=false
on_error() {
  rc=$?
  if $created; then
    echo "deployment failed after VM creation; preserving VM $vmid for evidence" >&2
    qm config "$vmid" >&2 || true
    qm status "$vmid" >&2 || true
  fi
  exit "$rc"
}
trap on_error ERR

qm clone "$template" "$vmid" --name "$name" --full 1 --storage "$storage"
created=true
qm set "$vmid" --cores "$cores" --memory "$memory" \
  --net0 "virtio,bridge=$primary_bridge" \
  --net1 "virtio,bridge=$secondary_bridge,mtu=$secondary_mtu"
qm set "$vmid" --scsi1 "$storage:$models_size,discard=on,ssd=1,iothread=1"
qm set "$vmid" \
  --ciuser "$ciuser" \
  --sshkeys "$ssh_public_key_file" \
  --ciupgrade 0 \
  --nameserver "$dns_servers" \
  --searchdomain "$search_domain" \
  --ipconfig0 "ip=$primary_ip,gw=$primary_gw" \
  --ipconfig1 "ip=$secondary_ip"
qm set "$vmid" --hostpci0 "$compute_fn,pcie=1,rombar=1"

config=$(qm config "$vmid")
grep -Eq "^scsi0: ${storage}:.*size=${root_size}G" <<<"$config" || { echo "root disk is not the expected cuda-katra clone" >&2; exit 69; }
grep -Eq "^scsi1: ${storage}:.*size=${models_size}G" <<<"$config" || { echo "model disk is not the expected ${models_size}G cuda-katra disk" >&2; exit 69; }
grep -Eq '^efidisk0: cuda-katra:' <<<"$config" || { echo "EFI disk is not on cuda-katra" >&2; exit 69; }
grep -Eq '^ide2: cuda-katra:.*cloudinit' <<<"$config" || { echo "cloud-init disk is not on cuda-katra" >&2; exit 69; }
grep -Eq '^net0: .*bridge=vmbr0' <<<"$config" || { echo "vmbr0 NIC missing" >&2; exit 69; }
grep -Eq '^net1: .*bridge=vmbr1.*mtu=9000' <<<"$config" || { echo "vmbr1 NIC/MTU missing" >&2; exit 69; }
grep -Eq "^hostpci0: .*01:00.0" <<<"$config" || { echo "direct GPU BDF missing" >&2; exit 69; }
grep -Fq "ipconfig0: ip=$primary_ip,gw=$primary_gw" <<<"$config" || { echo "primary cloud-init network missing" >&2; exit 69; }
grep -Fq "ipconfig1: ip=$secondary_ip" <<<"$config" || { echo "secondary cloud-init network missing" >&2; exit 69; }
! grep -Eq 'local-zfs:|^(scsi|ide|sata|efidisk)[0-9]*: local:' <<<"$config" \
  || { echo "unexpected VM disk on host boot storage" >&2; exit 69; }

$no_start || qm start "$vmid"
trap - ERR

echo "VM $vmid deployment candidate created successfully"
echo "hardware profile: $hardware_profile"
echo "model disk remains unformatted; guest bootstrap and acceptance remain separate gates"
