#!/usr/bin/env python3
import csv
import math
import statistics
import sys
from pathlib import Path

if len(sys.argv) != 2:
    raise SystemExit("usage: summarize.py SESSION_DIR")

root = Path(sys.argv[1])
host_file = root / "host-temps.tsv"
fan_file = root / "host-fans.tsv"
gpu_file = root / "gpu.csv"


def nums(values):
    out = []
    for value in values:
        try:
            number = float(str(value).strip())
        except (TypeError, ValueError):
            continue
        if math.isfinite(number):
            out.append(number)
    return out


def statline(label, values, unit=""):
    values = nums(values)
    if not values:
        return f"{label}: unavailable"
    return (
        f"{label}: min={min(values):.1f}{unit} "
        f"avg={statistics.fmean(values):.1f}{unit} max={max(values):.1f}{unit}"
    )

package = []
cores = []
all_host = {}
if host_file.exists():
    with host_file.open(newline="") as f:
        reader = csv.DictReader(f, delimiter="\t")
        for row in reader:
            value = row.get("temp_c")
            label = row.get("label", "")
            chip = row.get("chip", "")
            key = f"{chip}/{label}"
            all_host.setdefault(key, []).append(value)
            if chip == "coretemp" and label.startswith("Package id"):
                package.append(value)
            elif chip == "coretemp" and label.startswith("Core "):
                cores.append(value)

print("=== case telemetry summary ===")
print(statline("CPU package", package, " C"))
print(statline("CPU cores (all samples)", cores, " C"))

for key in sorted(all_host):
    if key.startswith("coretemp/"):
        continue
    values = nums(all_host[key])
    if values:
        print(statline(f"host sensor {key}", values, " C"))

host_fans = {}
if fan_file.exists():
    with fan_file.open(newline="") as f:
        reader = csv.DictReader(f, delimiter="\t")
        for row in reader:
            key = f"{row.get('chip', '')}/{row.get('label', '')}"
            host_fans.setdefault(key, []).append(row.get("rpm"))
for key in sorted(host_fans):
    print(statline(f"host fan {key}", host_fans[key], " RPM"))

gpu_rows = []
if gpu_file.exists():
    with gpu_file.open(newline="") as f:
        gpu_rows = list(csv.DictReader(f))

if not gpu_rows:
    print("GPU telemetry: unavailable")
    raise SystemExit(0)

fields = {
    "GPU temp": ("temperature.gpu", " C"),
    "GPU memory temp": ("temperature.memory", " C"),
    "GPU utilization": ("utilization.gpu", "%"),
    "GPU memory utilization": ("utilization.memory", "%"),
    "GPU fan": ("fan.speed", "%"),
    "GPU power": ("power.draw", " W"),
    "GPU graphics clock": ("clocks.gr", " MHz"),
    "GPU memory clock": ("clocks.mem", " MHz"),
    "GPU memory used": ("memory.used", " MiB"),
}
for label, (field, unit) in fields.items():
    print(statline(label, [r.get(field, "") for r in gpu_rows], unit))

pstates = [r.get("pstate", "").strip() for r in gpu_rows if r.get("pstate", "").strip()]
if pstates:
    counts = {p: pstates.count(p) for p in sorted(set(pstates))}
    print("GPU p-state samples: " + ", ".join(f"{k}={v}" for k, v in counts.items()))
