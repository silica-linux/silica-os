#!/bin/bash
# Builds the Silica OS container image and a bootable disk from it.
#
#   tools/build-image.sh [--repo URL | --no-packages] [--test] [--type qcow2] [--no-disk]
#
#   --repo URL      the dnf silica.repo of a silica-packages release (otherwise the RPMs in rpms/)
#   --no-packages   build without the Silica packages (SILICA_PACKAGES=none): checks the rest
#   --test          add the boot-test layer (test/Containerfile.boot-test) and build the disk
#                   from it, for tools/boot-test.sh
#   --type T        disk type for bootc-image-builder: qcow2 (default), raw;
#                   anaconda-iso is a TODO (installer with the user created by the installer)
#   --no-disk       only the container image
#
# Output: the image localhost/silica-os:latest (and :boot-test), the disk in output/<type>/.
#
# Root: bootc-image-builder runs as a privileged container and reads the image from root's
# container storage, so the image is built with root's podman too. The script uses sudo when it
# is not already root.
set -euo pipefail

cd "$(dirname "$0")/.."

repo=""
packages="required"
test_layer=0
disk_type="qcow2"
disk=1
bib_image="${BIB_IMAGE:-quay.io/centos-bootc/bootc-image-builder:latest}"

while [ $# -gt 0 ]; do
    case "$1" in
        --repo) repo="$2"; shift 2 ;;
        --no-packages) packages="none"; shift ;;
        --test) test_layer=1; shift ;;
        --type) disk_type="$2"; shift 2 ;;
        --no-disk) disk=0; shift ;;
        -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
        *) echo "unknown option: $1" >&2; exit 2 ;;
    esac
done

if [ "$disk_type" = "anaconda-iso" ]; then
    echo "anaconda-iso: not yet (TODO: installer kickstart with the user and the disk layout)" >&2
    exit 2
fi

sudo=""
if [ "$(id -u)" -ne 0 ]; then
    sudo="sudo"
fi
if ! command -v podman >/dev/null; then
    echo "podman not found: install podman (Fedora: dnf install podman, Ubuntu: apt install podman)" >&2
    exit 1
fi

echo "build-image: localhost/silica-os:latest (packages: ${repo:-${packages}})"
$sudo podman build \
    --build-arg SILICA_PACKAGES="$packages" \
    --build-arg SILICA_REPO_URL="$repo" \
    -t localhost/silica-os:latest \
    -f Containerfile .

image="localhost/silica-os:latest"
if [ "$test_layer" -eq 1 ]; then
    echo "build-image: localhost/silica-os:boot-test"
    $sudo podman build \
        --build-arg BASE=localhost/silica-os:latest \
        -t localhost/silica-os:boot-test \
        -f test/Containerfile.boot-test .
    image="localhost/silica-os:boot-test"
fi

if [ "$disk" -eq 0 ]; then
    exit 0
fi

mkdir -p output
echo "build-image: $disk_type disk from $image with $bib_image"
# Fedora has no default root filesystem in bootc-image-builder: xfs, like Fedora's own images.
$sudo podman run --rm --privileged --pull=newer \
    --security-opt label=type:unconfined_t \
    -v "$PWD/output:/output" \
    -v "$PWD/tools/bib-config.toml:/config.toml:ro" \
    -v /var/lib/containers/storage:/var/lib/containers/storage \
    "$bib_image" \
    --type "$disk_type" \
    --rootfs xfs \
    --use-librepo=True \
    "$image"

if [ -n "$sudo" ]; then
    $sudo chown -R "$(id -u):$(id -g)" output
fi
echo "build-image: $(ls output/"$disk_type"/*)"
