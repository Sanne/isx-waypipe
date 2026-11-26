#!/bin/sh
# Runs a Wayland client through the given waypipe, as both ends, against a headless weston.
# Needs weston and wayland-info. Usage: test-linux.sh <waypipe binary>
set -eu
waypipe=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
dir=$(mktemp -d /tmp/wp.XXXXXX) # short: a Unix socket path holds 107 bytes
chmod 700 "$dir"
export XDG_RUNTIME_DIR="$dir"
weston --backend=headless --socket=host-0 >"$dir/weston.log" 2>&1 &
weston=$!
trap 'kill $weston $client 2>/dev/null || true' EXIT
client=
i=0; while [ ! -S "$dir/host-0" ] && [ $i -lt 50 ]; do sleep 0.2; i=$((i+1)); done
WAYLAND_DISPLAY=host-0 "$waypipe" --no-gpu -s "$dir/c.sock" client >"$dir/client.log" 2>&1 &
client=$!
i=0; while [ ! -S "$dir/c.sock" ] && [ $i -lt 50 ]; do sleep 0.2; i=$((i+1)); done
globals=$("$waypipe" --no-gpu -s "$dir/c.sock" --display "$dir/guest-0" server -- sh -c 'wayland-info | grep -c interface')
echo "a client behind waypipe saw $globals globals of the compositor"
[ "$globals" -gt 5 ]
