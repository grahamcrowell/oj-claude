#!/usr/bin/env bash
# stale-hook-path — rename bin/oj-helper so the hooks.json command path
# no longer resolves. C3 must report "command path does not exist".
#
# $1 = target plugin root
set -euo pipefail
TARGET="${1:?usage: mutate.sh <target-plugin-root>}"
HELPER="${TARGET}/bin/oj-helper"
[[ -e "$HELPER" ]] || { echo "ERROR: $HELPER not found" >&2; exit 2; }
# Move the binary out from under hooks.json without rewriting hooks.json.
mv "$HELPER" "${TARGET}/bin/oj-helper.stale"
