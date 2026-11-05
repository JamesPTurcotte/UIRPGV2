#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

# Layout breakpoints must use the logical viewport. The project stretches with
# canvas_items/expand, so physical window sizes do not match Control coordinates.
bad_layout=$(grep -RInE "DisplayServer\.window_get_size|get_window\(\)\.size|OS\.get_window_size" src/presentation | grep -v 'src/presentation/layout/viewport_frame.gd' || true)
if [[ -n "$bad_layout" ]]; then
  echo "layout: use Responsive / get_viewport_rect instead of the OS window size:" >&2
  echo "$bad_layout" >&2
  exit 1
fi

# First import builds the global class cache and imports fonts.
godot --headless --path . --editor --quit
godot --headless --path . res://tests/test_runner.tscn
