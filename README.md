# eBPF Workouts

A workspace for small, focused eBPF experiments. Each workout is self-contained so it can use the language, libraries, and kernel features that best fit the exercise.

## Layout

- `workouts/_template/`: copy this when starting a new workout.
- `workouts/01-hello-world/`: first load-and-observe exercise.
- `workouts/02-maps/`: map types and userspace interaction.
- `workouts/03-tracing/`: tracepoints, kprobes, and event output.
- `workouts/04-xdp/`: packet processing with XDP.
- `workouts/05-tc/`: traffic control programs.

Each workout can contain `bpf/`, `userspace/`, `scripts/`, `tests/`, and `notes/` as needed. Keep commands and kernel/toolchain prerequisites in that workout's README.

## Start a workout

Copy `workouts/_template/` to a new numbered directory, then fill in its README. For example:

```sh
cp -a workouts/_template workouts/06-ring-buffer
```

Build outputs and common generated artifacts are ignored by Git.




### aya tools
```bash
aya-tool generate task_struct > myapp-ebpf/src/vmlinux.rs

```