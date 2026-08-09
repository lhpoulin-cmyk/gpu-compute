#!/usr/bin/env python3
import csv
import math
import re
import statistics
import sys
from collections import Counter
from pathlib import Path

if len(sys.argv) != 2:
    raise SystemExit("usage: summarize.py SESSION_DIR")

root = Path(sys.argv[1])
host_file = root / "host-temps.tsv"
fan_file = root / "host-fans.tsv"
cpu_file = root / "host-cpu.tsv"
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


def first_number(value):
    match = re.search(r"[-+]?(?:\d+(?:\.\d*)?|\.\d+)", str(value))
    return float(match.group(0)) if match else None


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

cpu_busy = []
if cpu_file.exists():
    with cpu_file.open(newline="") as f:
        reader = csv.DictReader(f, delimiter="\t")
        cpu_busy = [row.get("busy_percent") for row in reader]
print(statline("Host CPU busy", cpu_busy, "%"))

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

pcie_states = Counter()
loaded_pcie_states = Counter()
max_speed = None
max_width = None
for row in gpu_rows:
    speed_text = (row.get("pcie.link.speed") or "").strip()
    width_text = (row.get("pcie.link.width") or "").strip()
    if not speed_text or not width_text:
        continue
    state = f"{speed_text} x{width_text}"
    pcie_states[state] += 1
    speed = first_number(speed_text)
    width = first_number(width_text)
    if speed is not None and (max_speed is None or speed > max_speed):
        max_speed = speed
    if width is not None and (max_width is None or width > max_width):
        max_width = width
    util = first_number(row.get("utilization.gpu", ""))
    if util is not None and util >= 10.0:
        loaded_pcie_states[state] += 1

if pcie_states:
    print("PCIe link samples: " + ", ".join(f"{state}={count}" for state, count in sorted(pcie_states.items())))
else:
    print("PCIe link samples: unavailable")

if loaded_pcie_states:
    print("PCIe loaded-link samples (GPU util >=10%): " + ", ".join(
        f"{state}={count}" for state, count in sorted(loaded_pcie_states.items())
    ))
else:
    print("PCIe loaded-link samples (GPU util >=10%): unavailable")

if max_speed is not None and max_width is not None:
    print(f"PCIe max observed: {max_speed:g} GT/s x{int(max_width)}")
