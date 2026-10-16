#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
STATE="$ROOT/.cache/ebpf-vm"
PORT=${EBPF_VM_PORT:-2222}
IMAGE=noble-server-cloudimg-amd64.img
URL=https://cloud-images.ubuntu.com/noble/current

need() { command -v "$1" >/dev/null || { echo "Missing command: $1 (see vm/README.md)" >&2; exit 1; }; }
ssh_options=(-i "$STATE/id_ed25519" -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new -o "UserKnownHostsFile=$STATE/known_hosts")

case "${1:-help}" in
  setup)
    for tool in curl sha256sum qemu-img cloud-localds ssh-keygen python3; do need "$tool"; done
    mkdir -p "$STATE"
    if [[ ! -f "$STATE/$IMAGE" ]]; then
      curl --fail --location "$URL/$IMAGE" -o "$STATE/$IMAGE.part"
      curl --fail --location "$URL/SHA256SUMS" -o "$STATE/SHA256SUMS"
      python3 - "$STATE" "$IMAGE" <<'PY'
import hashlib
import pathlib
import sys
state, name = pathlib.Path(sys.argv[1]), sys.argv[2]
entries = dict(line.split(maxsplit=1)[::-1] for line in (state / 'SHA256SUMS').read_text().splitlines())
expected = entries.get(name) or entries.get('*' + name)
if not expected:
    raise SystemExit('Image checksum missing from SHA256SUMS')
with (state / (name + '.part')).open('rb') as stream:
    actual = hashlib.file_digest(stream, 'sha256').hexdigest()
if actual != expected:
    raise SystemExit('Image checksum mismatch; run setup again')
(state / (name + '.part')).rename(state / name)
PY
    fi
    if [[ ! -f "$STATE/id_ed25519" ]]; then
      ssh-keygen -t ed25519 -N '' -f "$STATE/id_ed25519" -C ebpf-lab
    fi
    if [[ ! -f "$STATE/disk.qcow2" ]]; then
      qemu-img create -f qcow2 -F qcow2 -b "$STATE/$IMAGE" "$STATE/disk.qcow2" 30G
    fi
    cat > "$STATE/meta-data" <<'EOF'
instance-id: ebpf-lab-v1
local-hostname: ebpf-lab
EOF
    cat > "$STATE/user-data" <<EOF
#cloud-config
users:
  - name: ebpf
    groups: [sudo]
    shell: /bin/bash
    sudo: ALL=(ALL) NOPASSWD:ALL
    lock_passwd: true
    ssh_authorized_keys:
      - $(cat "$STATE/id_ed25519.pub")
ssh_pwauth: false
package_update: true
packages:
  - build-essential
  - pkg-config
  - libssl-dev
  - clang
  - llvm
  - libelf-dev
  - zlib1g-dev
  - curl
  - git
  - strace
  - linux-tools-common
runcmd:
  - [sh, -c, 'mountpoint -q /sys/kernel/tracing || mount -t tracefs tracefs /sys/kernel/tracing']
EOF
    cloud-localds "$STATE/seed.img" "$STATE/user-data" "$STATE/meta-data"
    echo "Ready. Run: bash vm/ebpf-vm.sh start"
    ;;
  start|snapshot)
    need qemu-system-x86_64
    [[ -f "$STATE/seed.img" ]] || { echo 'Run setup first.' >&2; exit 1; }
    accel=(-accel tcg -cpu max)
    if [[ -r /dev/kvm && -w /dev/kvm ]]; then
      accel=(-accel kvm -cpu host)
    else
      echo 'KVM unavailable: using slower software emulation.' >&2
    fi
    extra=()
    [[ "$1" != snapshot ]] || extra=(-snapshot)
    exec qemu-system-x86_64 "${accel[@]}" \
      -m "${EBPF_VM_MEMORY:-4096}" -smp "${EBPF_VM_CPUS:-2}" \
      -drive "file=$STATE/disk.qcow2,format=qcow2,if=virtio" \
      -drive "file=$STATE/seed.img,format=raw,if=virtio,readonly=on" \
      -nic "user,model=virtio-net-pci,hostfwd=tcp:127.0.0.1:$PORT-:22" \
      -display none -serial mon:stdio -no-reboot "${extra[@]}"
    ;;
  ssh)
    shift
    exec ssh "${ssh_options[@]}" -p "$PORT" ebpf@127.0.0.1 "$@"
    ;;
  copy)
    [[ $# == 2 && -f "$2" ]] || { echo 'Usage: bash vm/ebpf-vm.sh copy /path/to/binary' >&2; exit 1; }
    exec scp "${ssh_options[@]}" -P "$PORT" "$2" ebpf@127.0.0.1:
    ;;
  *)
    echo 'Usage: bash vm/ebpf-vm.sh {setup|start|snapshot|ssh [command...]|copy /path/to/binary}'
    ;;
esac
