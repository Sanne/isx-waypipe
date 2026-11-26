#!/bin/sh
# Builds a static Linux waypipe from the pinned upstream commit. Runs inside Alpine (a container
# in CI), as root, for the architecture it runs on. Usage: build-linux.sh <output directory>
#
# Static, with lz4 and zstd linked in and no GPU or video support: the binary is attached to isx
# guests of any distribution and must need nothing of them. isx runs waypipe with --no-gpu.
set -eu
out=${1:?usage: build-linux.sh <output directory>}
here=$(cd "$(dirname "$0")" && pwd)
. "$here/pins.env"

apk add --no-cache git cargo rust rust-bindgen clang-libclang pkgconf musl-dev \
    lz4-dev lz4-static zstd-dev zstd-static >&2

src=$(mktemp -d)
git init -q "$src"
git -C "$src" fetch -q --depth 1 "$WAYPIPE_REPO" "$WAYPIPE_COMMIT"
git -C "$src" checkout -q FETCH_HEAD
[ "$(git -C "$src" rev-parse HEAD)" = "$WAYPIPE_COMMIT" ]

cd "$src"
# crt-static: Alpine's rustc links musl dynamically unless told otherwise.
# The release profile keeps full debug info, which the binary does not ship with.
RUSTFLAGS="-C target-feature=+crt-static" \
    cargo build --release --locked --no-default-features --features lz4,zstd --bin waypipe >&2

arch=$(uname -m)
mkdir -p "$out"
bin="$out/waypipe-$WAYPIPE_VERSION-linux-$arch"
cp target/release/waypipe "$bin"
strip "$bin"

# It must be static, and it must run.
if readelf -d "$bin" 2>/dev/null | grep -q NEEDED; then
    echo "ERROR: $bin is not static:" >&2
    readelf -d "$bin" | grep NEEDED >&2
    exit 1
fi
"$bin" --version | grep -q "^waypipe $WAYPIPE_VERSION\$"
"$bin" --version >&2
echo "$bin"
