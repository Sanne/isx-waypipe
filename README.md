# isx-waypipe

Builds of [waypipe](https://gitlab.freedesktop.org/mstoeckl/waypipe) for [isx](https://github.com/Sanne/incus-spawn), which uses it to show the windows of a Linux instance on a Mac.

waypipe carries the Wayland protocol over a byte stream.
isx runs one end on the Mac, beside a Wayland compositor, and the other in the instance, beside the application.
Both ends must be the same version, so this repository builds both from one upstream release.

## What is built

| Asset | Built from | Runs |
| --- | --- | --- |
| `waypipe-<version>-linux-x86_64` | upstream waypipe, unmodified | in an instance |
| `waypipe-<version>-linux-aarch64` | upstream waypipe, unmodified | in an instance |
| `waypipe-<version>-macos-aarch64` | [waypipe-darwin](https://github.com/J-x-Z/waypipe-darwin), upstream plus a macOS port | on the Mac |

`pins.env` names the exact commit of each source.

The Linux binaries are static, with lz4 and zstd linked in, so one file runs in a guest of any distribution and needs nothing installed there.
They have no GPU or video support: an isx instance has no GPU, and isx runs waypipe with `--no-gpu`.
The macOS binary loads only macOS's own libraries, so it needs no Homebrew.

## Releases

A tag `v<waypipe version>-isx.<n>` publishes the three binaries, a `SHA256SUMS` over them, and the source of each as a tarball.
isx pins a release's URL and sum and downloads the binaries when a person first uses GUI on a Mac.

## Building

```shell
./build-linux-in-alpine.sh out   # on Linux, for this machine's architecture; needs sudo
./build-macos.sh out             # on a Mac; needs Rust and: brew install bindgen pkgconf lz4 zstd
./test-linux.sh out/waypipe-*-linux-*
```

The Linux build runs in a chroot of Alpine's minirootfs, checked against the sum in `pins.env` before anything in it runs.

## Moving to a new waypipe

1. Wait for waypipe-darwin to carry the new upstream release, since the two ends must match.
2. Set the version and both commits in `pins.env`.
3. Open a pull request: CI builds all three and runs a client through the Linux one.
4. Try the macOS binary against the Linux one on a real Mac, then tag.

## Licence

waypipe is GPL-3.0-or-later, and so is everything here; see `LICENSE`.
Each release carries the source of its binaries.
