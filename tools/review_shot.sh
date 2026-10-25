#!/usr/bin/env bash
set -euo pipefail
if (( $# < 1 )); then
    echo 'Usage: tools/review_shot.sh <png> [focus text]' >&2
    exit 2
fi
png="$(realpath -e -- "$1")"
shift
if [[ ! -f "$png" ]]; then
    echo "Image not found: $png" >&2
    exit 1
fi
prompt="Act as a low-poly, bright toy-like FPS art director for Household Havoc, a dollhouse-scale shooter in a giant kitchen. Inspect the image at: $png
Critique readability, color, lighting, scale, and composition in at most 8 bullets. Give concrete, prioritized improvements grounded in the screenshot. Additional focus: ${*:-overall visual quality}. Do not modify any files."
agy -p "$prompt" --add-dir "$(dirname -- "$png")" --mode plan < /dev/null
