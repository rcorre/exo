#!/usr/bin/env bash
# Renders one frame of a scene to a PNG for visual inspection, off-screen via
# Xvfb (a real GPU-rendered frame, but no window appears on the real display).
# Falls back to a real window if xvfb-run isn't installed.
# Usage: tools/screenshot.sh <scene_path> <output_png_path> [wait_frames]
set -euo pipefail

if [ $# -lt 2 ]; then
	echo "usage: tools/screenshot.sh <scene_path> <output_png_path> [wait_frames]" >&2
	exit 2
fi

scene="$1"
out="$2"
frames="${3:-30}"

if command -v xvfb-run > /dev/null; then
	xvfb-run --auto-servernum --server-args="-screen 0 1280x720x24" \
		godot --script tools/screenshot.gd -- "$scene" "$out" "$frames"
else
	godot --script tools/screenshot.gd -- "$scene" "$out" "$frames"
fi
