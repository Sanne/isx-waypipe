#!/bin/sh
# Builds waypipe for macOS from the pinned waypipe-darwin commit, for the architecture it runs
# on. Needs Xcode's command line tools, Rust, and Homebrew's bindgen, pkgconf, lz4 and zstd.
# Usage: build-macos.sh <output directory>
#
# lz4 and zstd are linked in, so the binary needs nothing Homebrew installs: isx downloads it to
# a Mac that may have no Homebrew at all.
set -eu
out=${1:?usage: build-macos.sh <output directory>}
here=$(cd "$(dirname "$0")" && pwd)
. "$here/pins.env"

src=$(mktemp -d)
git init -q "$src"
git -C "$src" fetch -q --depth 1 "$DARWIN_REPO" "$DARWIN_COMMIT"
git -C "$src" checkout -q FETCH_HEAD
[ "$(git -C "$src" rev-parse HEAD)" = "$DARWIN_COMMIT" ]

# The wrappers ask the linker for -llz4 and -lzstd, and it prefers a .dylib beside a .a. So the
# build sees a directory that holds the static libraries alone, through pkg-config files that
# name it.
static=$(mktemp -d)
mkdir "$static/lib" "$static/pkgconfig"
for lib in lz4 zstd; do
    prefix=$(brew --prefix "$lib")
    cp "$prefix/lib/lib$lib.a" "$static/lib/"
    sed "s|^libdir=.*|libdir=$static/lib|" "$prefix/lib/pkgconfig/lib$lib.pc" > "$static/pkgconfig/lib$lib.pc"
done
export PKG_CONFIG_PATH="$static/pkgconfig"
export PKG_CONFIG_LIBDIR="$static/pkgconfig"

# bindgen loads libclang; Xcode's is not on its search path.
if [ -z "${LIBCLANG_PATH:-}" ]; then
    LIBCLANG_PATH="$(xcode-select -p)/Toolchains/XcodeDefault.xctoolchain/usr/lib"
    [ -e "$LIBCLANG_PATH/libclang.dylib" ] || LIBCLANG_PATH="$(xcode-select -p)/usr/lib"
    export LIBCLANG_PATH
fi

cd "$src"
cargo build --release --locked --no-default-features --features lz4,zstd --bin waypipe >&2

arch=$(uname -m)
[ "$arch" = arm64 ] && arch=aarch64
mkdir -p "$out"
bin="$out/waypipe-$WAYPIPE_VERSION-macos-$arch"
cp target/release/waypipe "$bin"
strip "$bin"
# Stripping breaks the linker's ad-hoc signature, without which an arm64 Mac refuses to run it.
codesign --force --sign - "$bin"

# It must load nothing but the system's own libraries, and it must run.
if otool -L "$bin" | tail -n +2 | grep -v -e '^[[:space:]]*/usr/lib/' -e '^[[:space:]]*/System/'; then
    echo "ERROR: $bin loads a library that is not macOS's own (listed above)" >&2
    exit 1
fi
"$bin" --version | grep -q "^waypipe $WAYPIPE_VERSION"
"$bin" --version >&2
echo "$bin"
