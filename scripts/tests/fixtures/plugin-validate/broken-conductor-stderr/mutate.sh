#!/usr/bin/env bash
# broken-conductor-stderr — remove CONDUCTOR.md from the plugin root.
# hooks.json still wires conductor-inject, so C5 must fire with a
# conductor-consistency violation.
#
# $1 = target plugin root
set -euo pipefail
TARGET="${1:?usage: mutate.sh <target-plugin-root>}"
CMD="${TARGET}/CONDUCTOR.md"
[[ -e "$CMD" ]] || { echo "ERROR: $CMD not found" >&2; exit 2; }
rm -f "$CMD"
