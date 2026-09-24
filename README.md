# sdash

`sdash` is a terminal dashboard for Slurm node resources. It groups nodes by
partition and shows CPU, memory, GPU, users, and an estimated next job release.
Each refresh runs one `sinfo` query and one `squeue` query; the rest is calculated
locally.

## Requirements

- Python 3.9 or newer (standard library only)
- Slurm's `sinfo` and `squeue` commands on `PATH`
- Access to a Slurm cluster from the machine running the command

Run it from this repository with `./bin/sdash`. To use `sdash` from any directory,
add this repository's `bin` directory to your `PATH`.

## Usage

```text
./bin/sdash                    # One snapshot
./bin/sdash --all              # Include all partitions exposed by Slurm
./bin/sdash --watch 5          # Refresh every five seconds; Ctrl-C to stop
./bin/sdash --no-color         # Plain output
./bin/sdash --help
```

`--watch` (or `-w`) accepts a positive number of seconds. `--all` (or `-a`)
adds `--all` to the `sinfo` query. Colors appear only when output is a terminal;
`--no-color` or the `NO_COLOR` environment variable disables them.

## Reading the dashboard

Each partition has a summary of its node count and allocated CPU, memory, and
GPU resources. A node belonging to multiple partitions appears in each of those
partitions, so adding partition summaries together can count it more than once.

| Column | Meaning |
| --- | --- |
| NODE | Physical node name. |
| STATE | Slurm node state. An otherwise usable `IDLE+POWERED_DOWN` node is shown as `IDLE`. |
| CPU USED | Allocated CPUs / total CPUs. |
| RAM USED | Allocated memory / total memory. Values come from Slurm in MiB and are displayed as GB or TB using binary conversion. |
| GPU USED | Used / configured GPUs, grouped by GPU type. `—` means no GPU GRES was reported. |
| USERS | Users with resource-owning jobs on the node. |
| NEXT RELEASE | Earliest known remaining time and user for a relevant job when a resource is full. |

Available nodes are sorted by their highest CPU, memory, or GPU usage percentage,
then by name. Unavailable nodes appear last and are grey when colors are enabled.
Other colors reflect that highest usage percentage, from green for free capacity
to red for full capacity.

`NEXT RELEASE` shows a GPU job's remaining time when GPUs are full. Otherwise,
when CPUs or memory are full, it shows the earliest remaining time among jobs on
the node. `?` means the relevant resource is full but no usable release time was
found; `—` means none of those resources is full. These are job time limits
reported by Slurm, not guaranteed times when the node will become available.

## Scope and limitations

Without `--all`, `sinfo` applies its usual visibility rules. This approximates
which partitions the current user's groups can see; it does not check account,
QOS, or reservation rules for a specific allocation. The `squeue` query always
uses `--all`, because a job in another partition can consume resources on a
shared node.

GPU release estimates use per-node GPU TRES where available and fall back to
job-level TRES. Heterogeneous multi-node jobs can make the latter imprecise.
The dashboard reports current Slurm state and allocations; it does not predict
queue priority or when a new job will start.
