#!/usr/bin/env bash
set -euo pipefail
if (( $# < 1 )); then
    echo 'Usage: tools/shot.sh <out.png> [extra user args...]' >&2
    exit 2
fi
repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
out="$(realpath -m -- "$1")"
shift
# Removing a previous capture ensures the existence check verifies this run.
if [[ -e "$out" ]]; then
    rm -- "$out"
fi
timeout 60s godot --path "$repo_root" --resolution 1280x720 -- "--screenshot=$out" "$@"
if [[ ! -s "$out" ]]; then
    echo "Screenshot was not created: $out" >&2
    exit 1
fi
