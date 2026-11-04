#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

# These cover the reference aspect, the minimum window, a 5:4 window, a 16:10
# window at the old physical-threshold trap, and a high-resolution 16:9 window.
for size in 1280x720 1440x900 1800x1125 1920x1080 1280x1024 2560x1440 1000x1000 960x960 960x720; do
  echo "layout audit: $size"
  godot --path . res://tests/layout_audit.tscn -- --size="$size"
done
