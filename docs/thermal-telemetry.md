# Case thermal telemetry

The reference RTX 5070 Ti appliance spans two telemetry domains:

- `hv-katra` owns CPU/package/core, PCH, NVMe, and other host hwmon sensors;
- VM 320 owns the passed-through RTX 5070 Ti and therefore supplies NVIDIA telemetry with `nvidia-smi`.

`telemetry/capture-case-session.sh` samples both sides together and stores the raw session under the ignored local evidence path:

```text
evidence/telemetry/<UTC timestamp>-<label>/
```

No telemetry daemon, database, Prometheus, or Grafana stack is required. Sessions are deliberately bounded and evidence-oriented.

## Captured host data

Once per interval, every readable `/sys/class/hwmon/hwmon*/temp*_input` value is recorded with its hwmon chip name and sensor label in `host-temps.tsv`.

This includes Intel `coretemp` package/core sensors and also captures PCH/NVMe/other case-relevant temperature sensors when the kernel exposes them.

## Captured GPU data

VM 320 is sampled over one persistent SSH session with `nvidia-smi`. `gpu.csv` records:

- GPU temperature;
- GPU memory temperature when supported;
- GPU and memory utilization;
- fan percentage;
- board power draw;
- p-state;
- graphics and memory clocks;
- used/total VRAM.

Full `nvidia-smi -q` thermal/power/performance snapshots are saved before and after the timed session.

## Run a session

From `/srv/cuda-compute` on `hv-katra`:

```bash
telemetry/capture-case-session.sh \
  --label idle-closed \
  --seconds 600
```

Defaults:

- guest: `louis@192.168.10.92`;
- VMID: `320`;
- interval: 1 second;
- duration: 300 seconds.

Useful labels include `idle-closed`, `gpu-inference`, `cpu-load`, `combined-load`, and later physical configuration names such as `front-fan-reversed` or `side-panel-off`.

## Interpretation

The goal is repeatable comparison, not a single dramatic maximum. For each physical configuration, use the same room conditions and the same workload where practical, and compare:

- CPU package average/max;
- hottest CPU-core samples;
- GPU average/max temperature;
- GPU power and utilization during the temperature result;
- GPU fan response;
- PCH/NVMe temperatures;
- any thermal or power limiting evidence in the before/after NVIDIA snapshots.

`telemetry/summarize.py` runs automatically at the end of capture and writes `summary.txt` with min/average/max values.

Raw telemetry under `evidence/telemetry/` is intentionally ignored by Git. Promote only a deliberately selected result or encrypted evidence bundle when a session becomes part of an accepted appliance decision.
