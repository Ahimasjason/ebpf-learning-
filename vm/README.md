# QEMU eBPF lab

Run experimental BPF programs in this VM so they execute against the guest kernel. Keep your editor on the host. The launcher exposes SSH only on localhost and does not share host directories or devices with the guest. QEMU runs as your normal user.

## Install and boot

On your Ubuntu host:

```sh
sudo apt update
sudo apt install qemu-system-x86 qemu-utils cloud-image-utils curl openssh-client
bash vm/ebpf-vm.sh setup
bash vm/ebpf-vm.sh start
```

Setup downloads an Ubuntu 24.04 x86_64 cloud image, verifies its SHA256 checksum against the HTTPS manifest, creates an SSH key and a 30 GB expandable guest disk under `.cache/ebpf-vm/`. Allow several minutes for first boot and package installation. Software emulation can take substantially longer.

In a second host terminal:

```sh
bash vm/ebpf-vm.sh ssh
sudo cloud-init status --wait
uname -r
test -r /sys/kernel/btf/vmlinux && echo 'Kernel BTF available'
```

If SSH initially refuses the connection, wait for the guest to finish booting and retry. SSH uses the dedicated key inside `.cache/ebpf-vm/`; the guest user is `ebpf` with passwordless sudo.

KVM accelerates the VM when `/dev/kvm` is accessible. Otherwise the launcher uses software emulation. If this host is itself a VM, KVM typically requires nested virtualization enabled by the outer host. No KVM is needed for the fallback.

## Build on the host, run in the guest

A host binary linked against a newer glibc may not run on Ubuntu 24.04. Build a static musl userspace binary for this workflow:

```sh
rustup target add x86_64-unknown-linux-musl
cd workouts/01-hello-world/hello-world
cargo build --release --package hello-world \
  --target=x86_64-unknown-linux-musl \
  --config='target.x86_64-unknown-linux-musl.linker="rust-lld"'
cd ../../..
bash vm/ebpf-vm.sh copy workouts/01-hello-world/hello-world/target/x86_64-unknown-linux-musl/release/hello-world
bash vm/ebpf-vm.sh ssh
```

Inside the guest:

```sh
chmod +x ~/hello-world
sudo env RUST_LOG=info ~/hello-world
```

Keep the loader running. Open another host terminal and trigger the guest probe:

```sh
bash vm/ebpf-vm.sh ssh /bin/ls
```

Aya `info!` logs appear in the loader terminal. For `bpf_printk!`, open another SSH session and read the **guest's** trace pipe:

```sh
bash vm/ebpf-vm.sh ssh
sudo cat /sys/kernel/tracing/trace_pipe
```

Use `cargo build` on the host and run the copied binary in the guest. This project's `cargo run` runner uses `sudo -E` and would load BPF into the host kernel if run on the host.

## Preserve a baseline and discard experiments

First finish initial setup using `start`. Shut down cleanly inside the guest:

```sh
sudo poweroff
```

For subsequent experiments:

```sh
bash vm/ebpf-vm.sh snapshot
```

Snapshot mode discards guest disk changes when QEMU exits, including copied programs and guest log files. Copy each new build again after boot. Use `start` when you intend to persist guest changes. Run only one instance against this disk at a time.

The serial console uses Ctrl-a then x to exit QEMU if the guest hangs. `-no-reboot` exits on a guest reboot rather than looping. Restart in snapshot mode to recover your baseline after a crash.

Optional launcher settings: `EBPF_VM_PORT=2223`, `EBPF_VM_MEMORY=4096` (MiB), `EBPF_VM_CPUS=2`. Use the same port setting for SSH/copy commands.

References: [QEMU invocation and snapshot mode](https://www.qemu.org/docs/master/system/invocation.html), [cloud-init NoCloud](https://cloudinit.readthedocs.io/en/latest/reference/datasources/nocloud.html), [Ubuntu cloud images](https://cloud-images.ubuntu.com/noble/current/).
