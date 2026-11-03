# Linux Out-of-Memory Process Selection Demo

A small Linux kernel learning project that demonstrates how Linux reacts to an out-of-memory condition and how `oom_score` and `oom_score_adj` influence which process is selected for termination.

This project was created as part of my **Kernel Development Learning Pipeline (KDLP)** work.

---

## Project Objective

The main goal of this project is to answer one question:

> **When Linux runs out of memory, how does the kernel decide which process should be stopped?**

The demo creates several controlled memory-consuming processes inside a memory-limited Podman container, changes the OOM preference of one process, then intentionally creates memory pressure.

The result can be observed directly through `/proc` and cgroup memory event counters.

---

## What This Project Demonstrates

- Linux out-of-memory behavior
- Process memory pressure
- `oom_score`
- `oom_score_adj`
- `/proc/<pid>/oom_score`
- `/proc/<pid>/oom_score_adj`
- cgroup memory limits
- `memory.events.local`
- Controlled process termination during an OOM event
- A small C program for allocating and holding memory
- Podman-based isolation for a safe live demo

---

## Environment

This project was tested with:

- Windows host
- PowerShell / Command Prompt
- Podman
- Fedora-based KDLP container
- GCC
- Linux cgroup v2
- x86-64 container environment

Container image used during development:

```text
f26_kdlp_container
```

The demo container is limited to approximately:

```text
256 MB RAM
```

This prevents the experiment from exhausting the host computer's memory.

---

## Project Structure

```text
KDLP_OOM/
|
|-- memhog.c
|-- KDLP_OOM_START.bat
|-- KDLP_OOM_LIVE_DEMO_FIXED.bat
|-- KDLP_OOM_Presentation.pptx
|-- README.md
```

### `memhog.c`

A small C program that:

1. Allocates a requested amount of memory.
2. Touches each memory page so Linux actually backs the allocation.
3. Keeps the process alive so the allocated memory remains in use.

Example:

```bash
/tmp/memhog 80 A
```

This creates a process labeled `A` that holds approximately 80 MiB of memory.

---

## Why the C Loop Is Important

Simply calling `malloc()` does not necessarily cause Linux to immediately allocate physical memory for every requested page.

The program touches the allocated memory page-by-page:

```c
for (size_t i = 0; i < bytes; i += 4096)
    memory[i] = 1;
```

This forces the pages to be faulted in and actually backed by memory.

The program then remains alive:

```c
while (1)
    sleep(1);
```

This keeps the memory allocated long enough to create controlled memory pressure.

---

## Setup

Run:

```cmd
KDLP_OOM_START.bat
```

The setup script:

- checks that Podman is available
- checks the KDLP container image
- compiles `memhog.c`
- creates a clean container
- limits the container to 256 MB
- copies the compiled `memhog` program into the container

When setup is complete, the terminal displays:

```text
READY
```

---

## Manual Demo

### 1. Start Process A

```cmd
podman exec -d oom-demo /tmp/memhog 80 A
```

Process A now holds approximately 80 MiB.

### 2. Start Process B

```cmd
podman exec -d oom-demo /tmp/memhog 80 B
```

Process B also holds approximately 80 MiB.

### 3. View Running Processes

```cmd
podman top oom-demo pid args
```

Example output:

```text
PID    COMMAND
1      /usr/bin/sleep infinity
3      /tmp/memhog 80 A
4      /tmp/memhog 80 B
```

The process IDs may be different on each run.

---

## Inspect OOM Scores

For Process A:

```cmd
podman exec oom-demo cat /proc/3/oom_score
podman exec oom-demo cat /proc/3/oom_score_adj
```

For Process B:

```cmd
podman exec oom-demo cat /proc/4/oom_score
podman exec oom-demo cat /proc/4/oom_score_adj
```

During one test, both processes initially had:

```text
oom_score     = 805
oom_score_adj = 200
```

---

## Change the OOM Preference

Increase Process A's `oom_score_adj`:

```cmd
podman exec oom-demo sh -c "echo 1000 > /proc/3/oom_score_adj"
```

Check the score again:

```cmd
podman exec oom-demo cat /proc/3/oom_score
podman exec oom-demo cat /proc/3/oom_score_adj
```

Observed result:

```text
Process A

oom_score_adj: 200  -> 1000
oom_score:     805  -> 1338
```

Process B remained:

```text
oom_score_adj = 200
oom_score     = 805
```

This made Process A a much stronger candidate during an OOM condition.

---

## Trigger Memory Pressure

Start Process C:

```cmd
podman exec -d oom-demo /tmp/memhog 120 C
```

The expected memory demand becomes approximately:

```text
A = 80 MiB
B = 80 MiB
C = 120 MiB

Total requested = 280 MiB
Container limit = 256 MiB
```

This intentionally pushes the container beyond its configured memory limit.

---

## Observe the Result

Check the running processes again:

```cmd
podman top oom-demo pid args
```

Observed result:

```text
PID    COMMAND
1      /usr/bin/sleep infinity
4      /tmp/memhog 80 B
24     /tmp/memhog 120 C
```

Process A disappeared.

The process with the highest OOM preference was selected when the container reached an out-of-memory condition.

---

## Confirm the OOM Event

Check the cgroup memory event counters:

```cmd
podman exec oom-demo cat /sys/fs/cgroup/memory.events.local
```

Observed output included:

```text
oom_kill 1
```

This confirms that one process was terminated as a result of an out-of-memory condition.

---

## Observed Experiment

Before memory pressure:

| Process | Memory | `oom_score_adj` | `oom_score` |
|---|---:|---:|---:|
| A | 80 MiB | 200 | 805 |
| B | 80 MiB | 200 | 805 |

After changing Process A:

| Process | Memory | `oom_score_adj` | `oom_score` |
|---|---:|---:|---:|
| A | 80 MiB | 1000 | 1338 |
| B | 80 MiB | 200 | 805 |

After adding Process C:

| Process | Result |
|---|---|
| A | Stopped during OOM event |
| B | Remained running |
| C | Remained running |

Kernel/cgroup evidence:

```text
oom_kill 1
```

---

## Main Result

The experiment shows that Linux does not simply choose a process randomly when memory is exhausted.

The kernel evaluates processes using OOM-related heuristics, and `oom_score_adj` can significantly influence that decision.

```text
Process A
    |
    | oom_score_adj = 1000
    v
Higher oom_score
    |
    v
Memory limit reached
    |
    v
OOM condition
    |
    v
Process A selected
```

---

## Related Linux Kernel Area

The Linux OOM implementation is primarily associated with:

```text
mm/oom_kill.c
```

Relevant concepts include:

- OOM process selection
- badness scoring
- memory reclaim failure
- process eligibility
- OOM adjustment values
- process termination
- cgroup-scoped OOM behavior

---

## Safety

The demo intentionally creates memory pressure.

Do **not** run uncontrolled memory-allocation tests directly on a production system.

This project uses a memory-limited container so the experiment remains isolated:

```text
--memory=256m
--memory-swap=256m
```

---

## What I Learned

This project helped me understand:

- how Linux exposes process OOM information through `/proc`
- how cgroups provide isolated memory limits
- how process memory usage affects kernel decisions
- how `oom_score_adj` changes process preference
- how to reproduce an OOM event in a controlled environment
- how to connect observable runtime behavior with Linux kernel source code

---

## Future Improvements

Possible extensions:

- compare several `oom_score_adj` values
- test negative adjustment values
- compare processes with different memory footprints
- inspect kernel logs during OOM handling
- trace OOM-related kernel functions
- compare global OOM behavior with cgroup OOM behavior
- automate multiple reproducible test cases

---

## Author

**Anatolie Jentimir**

Computer Science student  
Kernel Development Learning Pipeline (KDLP)

---

## Disclaimer

This repository is an educational kernel-development experiment. It intentionally creates memory pressure inside an isolated environment for learning and demonstration purposes.
