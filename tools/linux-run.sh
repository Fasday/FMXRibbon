#!/bin/sh
# Runs a Linux64 FMR Ribbon program (FMXWayland) on a private headless Weston: no screen, no input devices, own
# runtime dir and socket (fmr-ribbon-<pid>), so it never meets another compositor or test. Takes compositor
# screenshots with weston-screenshooter and lets the program dump its own frames (FMXWAYLAND_DUMP_DIR).
# Used by tools\linux-run.ps1.
#
#   linux-run.sh <out-dir> <scale> <width> <height> <program> [args...]
#
# Environment: SHOTS  seconds after the start at which screenshots are taken (default "4"; screen-1.png, ...)
#              RUN_FOR seconds the program runs in total (default: last shot + 1), then it gets SIGTERM
#              FMXWAYLAND_LOG (default 1)
set -u
OUT="$1"; SCALE="$2"; W="$3"; H="$4"; shift 4
PROG="$1"; shift
SHOTS="${SHOTS:-4}"
mkdir -p "$OUT"
RT=$(mktemp -d /tmp/fmr-ribbon-rt.XXXXXX)
chmod 700 "$RT"
SOCK="fmr-ribbon-$$"
export XDG_RUNTIME_DIR="$RT"
unset DISPLAY WAYLAND_DISPLAY
# --debug exposes weston_screenshooter to clients. Weston before 12 knows only the module name of the backend and
# --use-pixman (its headless backend draws nothing otherwise).
if weston --help 2>&1 | grep -q -- '--renderer='; then
  WARGS="--backend=headless --renderer=pixman"
else
  WARGS="--backend=headless-backend.so --use-pixman"
fi
weston $WARGS --width="$W" --height="$H" --scale="$SCALE" --socket="$SOCK" \
  --idle-time=0 --debug --log="$OUT/weston.log" 2> "$OUT/weston.stderr" &
WPID=$!
i=0
while [ ! -S "$RT/$SOCK" ] && [ $i -lt 50 ]; do sleep 0.1; i=$((i+1)); done
export WAYLAND_DISPLAY="$SOCK"
LAST=0
for s in $SHOTS; do LAST=$s; done
RUN_FOR="${RUN_FOR:-$((LAST + 1))}"
cd "$(dirname "$PROG")"
FMXWAYLAND_LOG="${FMXWAYLAND_LOG:-1}" FMXWAYLAND_DUMP_DIR="$OUT" timeout -s TERM "$RUN_FOR" "$PROG" "$@" \
  > "$OUT/program.log" 2>&1 &
PPID2=$!
T=0
N=0
for s in $SHOTS; do
  sleep $((s - T))
  T=$s
  N=$((N + 1))
  (cd "$OUT" && timeout 10 weston-screenshooter >> "$OUT/screenshooter.log" 2>&1)
  F=$(ls -t "$OUT"/wayland-screenshot*.png 2>/dev/null | head -n 1)
  [ -n "$F" ] && mv "$F" "$OUT/screen-$N.png"
  # The frame dumps of this moment (the program rewrites them on every repaint; a caret blinks).
  mkdir -p "$OUT/dump-$N"
  cp "$OUT"/*.bmp "$OUT/dump-$N/" 2>/dev/null
done
wait $PPID2
echo "exit=$?" >> "$OUT/program.log"
rm -f "$OUT"/*.bmp
kill $WPID 2>/dev/null
wait $WPID 2>/dev/null
rm -rf "$RT"
