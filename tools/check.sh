#!/usr/bin/env bash
# Run a headless Godot script and fail on non-zero exit OR on any engine
# error printed to output (Godot exits 0 on most *runtime* script errors,
# so exit-code alone is not a reliable pass/fail signal).
#
# Usage: tools/check.sh <script.gd> [-- <args passed to the script>]
set -euo pipefail

if [ $# -lt 1 ]; then
	echo "usage: tools/check.sh <script.gd> [-- <args>]" >&2
	exit 2
fi

script="$1"
shift

out=$(mktemp)
trap 'rm -f "$out"' EXIT

status=0
godot --headless --script "$script" "$@" > "$out" 2>&1 || status=$?

cat "$out"

if [ "$status" -ne 0 ]; then
	echo "FAIL: godot exited with status $status"
	exit 1
fi

if grep -qE 'SCRIPT ERROR|Parse Error|^ERROR:|Unhandled Exception' "$out"; then
	echo "FAIL: engine reported an error (see above)"
	exit 1
fi

echo "OK"
