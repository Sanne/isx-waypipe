#!/bin/sh
# Runs build-linux.sh in a chroot of the pinned Alpine minirootfs, for this machine's
# architecture. Needs sudo, curl and tar. Usage: build-linux-in-alpine.sh <output directory>
#
# A chroot, not a container image: the minirootfs is checked against a pinned sum before
# anything in it runs, and the same script runs on a CI runner and on a developer's machine.
set -eu
out=${1:?usage: build-linux-in-alpine.sh <output directory>}
here=$(cd "$(dirname "$0")" && pwd)
. "$here/pins.env"

arch=$(uname -m)
eval "sum=\${ALPINE_SHA256_$arch:-}"
[ -n "$sum" ] || { echo "ERROR: no Alpine minirootfs sum pinned for $arch" >&2; exit 1; }

work=$(mktemp -d)
url="https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VERSION%.*}/releases/$arch/alpine-minirootfs-$ALPINE_VERSION-$arch.tar.gz"
curl -fsSL -o "$work/minirootfs.tar.gz" "$url"
echo "$sum  $work/minirootfs.tar.gz" | sha256sum -c - >&2

root="$work/root"
mkdir "$root"
sudo tar -xzf "$work/minirootfs.tar.gz" -C "$root"
sudo cp /etc/resolv.conf "$root/etc/resolv.conf"
sudo mkdir -p "$root/work"
sudo cp "$here/build-linux.sh" "$here/pins.env" "$root/work/"
sudo mount -t proc proc "$root/proc"
# Only the device files the build needs, each bound by itself. Never the host's /dev as a tree:
# its mounts are shared, so unmounting a recursive bind of it unmounts the host's own /dev/pts.
devices="null zero random urandom"
for device in $devices; do
    sudo touch "$root/dev/$device"
    sudo mount --bind "/dev/$device" "$root/dev/$device"
done

# A host behind a TLS-inspecting proxy names its CA bundle in SSL_CERT_FILE; the chroot gets a copy.
set -- HOME=/root
if [ -n "${SSL_CERT_FILE:-}" ]; then
    sudo cp "$SSL_CERT_FILE" "$root/etc/ssl/host-ca.pem"
    set -- "$@" SSL_CERT_FILE=/etc/ssl/host-ca.pem CARGO_HTTP_CAINFO=/etc/ssl/host-ca.pem GIT_SSL_CAINFO=/etc/ssl/host-ca.pem
fi

status=0
sudo chroot "$root" /usr/bin/env "$@" /bin/sh /work/build-linux.sh /work/out >&2 || status=$?
for device in $devices; do sudo umount "$root/dev/$device" || true; done
sudo umount "$root/proc" || true
[ "$status" -eq 0 ] || exit "$status"

mkdir -p "$out"
sudo cp "$root"/work/out/waypipe-* "$out/"
sudo chown "$(id -u):$(id -g)" "$out"/waypipe-*
ls "$out"/waypipe-*
