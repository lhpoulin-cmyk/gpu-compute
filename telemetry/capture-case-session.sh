#!/usr/bin/env bash
set -Eeuo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
label=case-test
guest=louis@192.168.10.92
seconds=300
interval=1
vmid=320

while [[ $# -gt 0 ]]; do
  case "$1" in
    --label) label=${2:?}; shift 2 ;;
    --guest) guest=${2:?}; shift 2 ;;
    --seconds) seconds=${2:?}; shift 2 ;;
    --interval) interval=${2:?}; shift 2 ;;
    --vmid) vmid=${2:?}; shift 2 ;;
    *) echo "usage: capture-case-session.sh [--label NAME] [--guest USER@HOST] [--seconds N] [--interval SEC] [--vmid ID]" >&2; exit 64 ;;
  esac
done

[[ "$label" =~ ^[A-Za-z0-9._-]+$ ]] || { echo "invalid label" >&2; exit 64; }
[[ "$seconds" =~ ^[1-9][0-9]*$ ]] || { echo "invalid seconds" >&2; exit 64; }
[[ "$interval" =~ ^[0-9]+([.][0-9]+)?$ ]] || { echo "invalid interval" >&2; exit 64; }

for cmd in ssh qm python3; do command -v "$cmd" >/dev/null 2>&1 || { echo "missing command: $cmd" >&2; exit 69; }; done
[[ $(hostname -s) == hv-katra ]] || { echo "run this capture on hv-katra" >&2; exit 69; }
vm_status=$(qm status "$vmid")
[[ "$vm_status" == *"status: running"* ]] || { echo "VM $vmid is not running: $vm_status" >&2; exit 69; }
ssh -o BatchMode=yes -o ConnectTimeout=5 "$guest" 'command -v nvidia-smi >/dev/null && nvidia-smi -L >/dev/null' \
  || { echo "guest NVIDIA telemetry is not reachable: $guest" >&2; exit 69; }

guest_bdf=$(ssh -o BatchMode=yes "$guest" "nvidia-smi --query-gpu=pci.bus_id --format=csv,noheader | sed -n '1p' | tr -d '[:space:]'")
guest_bdf=${guest_bdf/00000000:/0000:}
[[ "$guest_bdf" =~ ^[0-9A-Fa-f]{4}:[0-9A-Fa-f]{2}:[0-9A-Fa-f]{2}\.[0-7]$ ]] \
  || { echo "could not resolve guest GPU BDF: $guest_bdf" >&2; exit 69; }
pcie_path="/sys/bus/pci/devices/$guest_bdf"
ssh -o BatchMode=yes "$guest" "test -r '$pcie_path/current_link_speed' -a -r '$pcie_path/current_link_width'" \
  || { echo "guest PCIe live-link telemetry unavailable for $guest_bdf" >&2; exit 69; }

stamp=$(date -u +%Y%m%dT%H%M%SZ)
out="$root/evidence/telemetry/${stamp}-${label}"
mkdir -p "$out"

{
  echo "session=$label"
  echo "started_utc=$stamp"
  echo "host=$(hostname -f 2>/dev/null || hostname)"
  echo "guest=$guest"
  echo "vmid=$vmid"
  echo "guest_gpu_bdf=$guest_bdf"
  echo "duration_seconds=$seconds"
  echo "interval_seconds=$interval"
  echo "repository_head=$(git -C "$root" rev-parse HEAD 2>/dev/null || echo unknown)"
} > "$out/session.env"

qm config "$vmid" > "$out/qm-config.txt"
uname -a > "$out/host-uname.txt"
ssh "$guest" 'uname -a; echo; nvidia-smi -q -d TEMPERATURE,POWER,PERFORMANCE,CLOCK,UTILIZATION' > "$out/gpu-before.txt"

host_tsv="$out/host-temps.tsv"
printf 'epoch_ms\tiso8601\thwmon\tchip\tlabel\ttemp_c\n' > "$host_tsv"

fan_tsv="$out/host-fans.tsv"
printf 'epoch_ms\tiso8601\thwmon\tchip\tlabel\trpm\n' > "$fan_tsv"

cpu_tsv="$out/host-cpu.tsv"
printf 'epoch_ms\tiso8601\tbusy_percent\n' > "$cpu_tsv"

gpu_csv="$out/gpu.csv"
printf 'timestamp,name,temperature.gpu,temperature.memory,utilization.gpu,utilization.memory,fan.speed,power.draw,pstate,clocks.gr,clocks.mem,memory.used,memory.total,pcie.link.speed,pcie.link.width\n' > "$gpu_csv"

collect_host() {
  local deadline=$((SECONDS + seconds))
  while (( SECONDS < deadline )); do
    local epoch iso hw chip input stem label_file sensor_label raw temp
    epoch=$(date +%s%3N)
    iso=$(date -Is)
    for hw in /sys/class/hwmon/hwmon*; do
      [[ -r "$hw/name" ]] || continue
      chip=$(<"$hw/name")
      for input in "$hw"/temp*_input; do
        [[ -r "$input" ]] || continue
        stem=${input%_input}
        label_file="${stem}_label"
        if [[ -r "$label_file" ]]; then
          sensor_label=$(<"$label_file")
        else
          sensor_label=$(basename "$stem")
        fi
        raw=$(<"$input")
        [[ "$raw" =~ ^-?[0-9]+$ ]] || continue
        temp=$(awk -v x="$raw" 'BEGIN { printf "%.3f", x/1000.0 }')
        printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$epoch" "$iso" "$(basename "$hw")" "$chip" "$sensor_label" "$temp" >> "$host_tsv"
      done
      for input in "$hw"/fan*_input; do
        [[ -r "$input" ]] || continue
        stem=${input%_input}
        label_file="${stem}_label"
        if [[ -r "$label_file" ]]; then
          sensor_label=$(<"$label_file")
        else
          sensor_label=$(basename "$stem")
        fi
        raw=$(<"$input")
        [[ "$raw" =~ ^[0-9]+$ ]] || continue
        printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$epoch" "$iso" "$(basename "$hw")" "$chip" "$sensor_label" "$raw" >> "$fan_tsv"
      done
    done
    sleep "$interval"
  done
}

read_cpu_counters() {
  local cpu user nice system idle iowait irq softirq steal rest
  read -r cpu user nice system idle iowait irq softirq steal rest < /proc/stat
  [[ "$cpu" == cpu ]] || return 1
  printf '%s %s\n' "$((user + nice + system + idle + iowait + irq + softirq + steal))" "$((idle + iowait))"
}

collect_cpu() {
  local deadline=$((SECONDS + seconds))
  local prev_total prev_idle total idle delta_total delta_idle busy epoch iso
  read -r prev_total prev_idle < <(read_cpu_counters)
  while (( SECONDS < deadline )); do
    sleep "$interval"
    read -r total idle < <(read_cpu_counters)
    delta_total=$((total - prev_total))
    delta_idle=$((idle - prev_idle))
    prev_total=$total
    prev_idle=$idle
    (( delta_total > 0 )) || continue
    busy=$(awk -v total="$delta_total" -v idle="$delta_idle" 'BEGIN { printf "%.3f", 100.0 * (total-idle) / total }')
    epoch=$(date +%s%3N)
    iso=$(date -Is)
    printf '%s\t%s\t%s\n' "$epoch" "$iso" "$busy" >> "$cpu_tsv"
  done
}

collect_gpu() {
  ssh "$guest" "pcie_path='$pcie_path'; end=\$((SECONDS+$seconds)); while (( SECONDS < end )); do gpu=\$(nvidia-smi --query-gpu=timestamp,name,temperature.gpu,temperature.memory,utilization.gpu,utilization.memory,fan.speed,power.draw,pstate,clocks.gr,clocks.mem,memory.used,memory.total --format=csv,noheader,nounits); speed=\$(cat \"\$pcie_path/current_link_speed\"); width=\$(cat \"\$pcie_path/current_link_width\"); printf '%s, %s, %s\\n' \"\$gpu\" \"\$speed\" \"\$width\"; sleep $interval; done" >> "$gpu_csv"
}

collect_host & host_pid=$!
collect_cpu & cpu_pid=$!
collect_gpu & gpu_pid=$!

cleanup() {
  kill "$host_pid" "$cpu_pid" "$gpu_pid" 2>/dev/null || true
  wait "$host_pid" "$cpu_pid" "$gpu_pid" 2>/dev/null || true
}
trap cleanup INT TERM EXIT

wait "$host_pid"
wait "$cpu_pid"
wait "$gpu_pid"
trap - INT TERM EXIT

ssh "$guest" 'nvidia-smi -q -d TEMPERATURE,POWER,PERFORMANCE,CLOCK,UTILIZATION' > "$out/gpu-after.txt"
python3 "$root/telemetry/summarize.py" "$out" | tee "$out/summary.txt"

echo "telemetry session complete: $out"
