#!/bin/sh
# Writes the exact source of each binary as a tarball, to publish beside the binaries: the
# GPL asks that whoever gets a binary can get its source from the same place.
# Usage: source-archives.sh <output directory>
set -eu
out=${1:?usage: source-archives.sh <output directory>}
here=$(cd "$(dirname "$0")" && pwd)
. "$here/pins.env"
mkdir -p "$out"
out=$(cd "$out" && pwd)

archive() { # <repo> <commit> <name>
    src=$(mktemp -d)
    git init -q "$src"
    git -C "$src" fetch -q --depth 1 "$1" "$2"
    [ "$(git -C "$src" rev-parse FETCH_HEAD)" = "$2" ]
    git -C "$src" archive --format=tar.gz --prefix="$3/" -o "$out/$3.tar.gz" FETCH_HEAD
    echo "$out/$3.tar.gz"
}
archive "$WAYPIPE_REPO" "$WAYPIPE_COMMIT" "waypipe-$WAYPIPE_VERSION-source"
archive "$DARWIN_REPO" "$DARWIN_COMMIT" "waypipe-darwin-${DARWIN_TAG#v}-source"
