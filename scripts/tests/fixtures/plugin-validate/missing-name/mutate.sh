#!/usr/bin/env bash
# missing-name — delete the .name field from plugin.json so C2 must fail
# with a missing-required-field diagnostic.
#
# $1 = target plugin root (a copy of oj-claude under a tempdir)
set -euo pipefail
TARGET="${1:?usage: mutate.sh <target-plugin-root>}"
PJ="${TARGET}/.claude-plugin/plugin.json"
[[ -r "$PJ" ]] || { echo "ERROR: $PJ not readable" >&2; exit 2; }
# Use tmp+mv (no `sponge` dependency).
tmp=$(mktemp "${PJ}.XXXXXX")
jq 'del(.name)' "$PJ" > "$tmp"
mv "$tmp" "$PJ"
