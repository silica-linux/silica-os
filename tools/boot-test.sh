#!/bin/bash
# Boots a Silica OS disk under QEMU/KVM and checks that the Silica session comes up on DRM/KMS:
# Ossido's control channel answers, the journal shows "drm backend ready", and ui.screenshot is
# not black. The disk must come from the boot-test layer (tools/build-image.sh --test), which
# forwards the control channel and logs to the serial console.
#
#   tools/boot-test.sh DISK.qcow2 [--port N] [--timeout SECONDS] [--out DIR] [--show] [--keep]
#
#   --port      host port forwarded to the guest's control channel (default 7992; never 7979 or
#               7980, the development sessions on the host)
#   --timeout   seconds to wait for the session (default 600)
#   --out       where screenshot.png and console.log go (default output/boot-test)
#   --show      a window with the guest's screen
#   --keep      leave the VM running after the check
#
# Same recipe as silica-desktop's `cargo xtask vm` (docs/vm.md): virtio-vga without 3D (Mesa
# renders in software into GBM dumb buffers), virtio keyboard and tablet for libinput, user
# networking with a host forward.
set -euo pipefail

cd "$(dirname "$0")/.."

disk=""
port=7992
timeout=600
out="output/boot-test"
show=0
keep=0
while [ $# -gt 0 ]; do
    case "$1" in
        --port) port="$2"; shift 2 ;;
        --timeout) timeout="$2"; shift 2 ;;
        --out) out="$2"; shift 2 ;;
        --show) show=1; shift ;;
        --keep) keep=1; shift ;;
        -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
        -*) echo "unknown option: $1" >&2; exit 2 ;;
        *) disk="$1"; shift ;;
    esac
done
if [ -z "$disk" ] || [ ! -f "$disk" ]; then
    echo "usage: tools/boot-test.sh DISK.qcow2 [options] (see --help)" >&2
    exit 2
fi
if [ "$port" = 7979 ] || [ "$port" = 7980 ]; then
    echo "port $port is reserved for the development sessions on the host" >&2
    exit 2
fi
for tool in qemu-system-x86_64 qemu-img python3; do
    command -v "$tool" >/dev/null || { echo "$tool not found (Ubuntu: apt install qemu-system-x86 qemu-utils)" >&2; exit 1; }
done

mkdir -p "$out"
overlay="$out/disk.qcow2"
console="$out/console.log"
screenshot="$out/screenshot.png"
rm -f "$overlay" "$console" "$screenshot"
# A throwaway overlay: the built disk stays untouched.
qemu-img create -q -f qcow2 -F qcow2 -b "$(realpath "$disk")" "$overlay"

accel=(-machine q35)
if [ -w /dev/kvm ]; then
    accel+=(-enable-kvm -cpu host)
else
    echo "boot-test: /dev/kvm not writable, emulating (slow)" >&2
fi
display=(-display none)
if [ "$show" -eq 1 ]; then
    display=(-display gtk)
fi

qemu-system-x86_64 "${accel[@]}" -m 4096 -smp 2 -no-reboot \
    -drive "file=$overlay,if=virtio,format=qcow2" \
    -vga none -device virtio-vga \
    -netdev "user,id=net0,hostfwd=tcp:127.0.0.1:${port}-:7990" \
    -device virtio-net-pci,netdev=net0 \
    -device virtio-keyboard-pci -device virtio-tablet-pci \
    -serial "file:$console" \
    "${display[@]}" &
qemu=$!
cleanup() {
    if [ "$keep" -eq 0 ] && kill -0 "$qemu" 2>/dev/null; then
        kill "$qemu" 2>/dev/null || true
        wait "$qemu" 2>/dev/null || true
    fi
}
trap cleanup EXIT

echo "boot-test: VM started (console in $console), waiting for the session on port $port"
deadline=$((SECONDS + timeout))
# QEMU accepts the connection even when nothing listens in the guest: only an answer counts.
until python3 tools/silica_control.py "127.0.0.1:$port" ping; do
    if ! kill -0 "$qemu" 2>/dev/null; then
        echo "boot-test: the VM stopped: see $console" >&2
        exit 1
    fi
    if [ "$SECONDS" -ge "$deadline" ]; then
        echo "boot-test: no control channel after ${timeout}s: see $console" >&2
        exit 1
    fi
    sleep 5
done
echo "boot-test: control channel up, waiting for the shell"
sleep 20

if ! grep -q "drm backend ready" "$console"; then
    echo "boot-test: Ossido answers but not on DRM (no \"drm backend ready\"): see $console" >&2
    exit 1
fi
python3 tools/silica_control.py "127.0.0.1:$port" screenshot "$screenshot"
share=$(python3 tools/silica_control.py - nonblack "$screenshot")
echo "boot-test: screenshot $screenshot ($(python3 -c "print(f'{$share * 100:.1f}')")% non-black pixels)"
if python3 -c "import sys; sys.exit(0 if $share >= 0.5 else 1)"; then
    echo "boot-test: ok"
else
    echo "boot-test: the frame is mostly black" >&2
    exit 1
fi
if [ "$keep" -eq 1 ]; then
    echo "boot-test: the VM keeps running (pid $qemu, control channel on 127.0.0.1:$port)"
    trap - EXIT
fi
