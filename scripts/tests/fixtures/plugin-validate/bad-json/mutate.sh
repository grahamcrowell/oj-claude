#!/usr/bin/env bash
# bad-json — corrupt plugin.json with an invalid JSON suffix so C1 fails
# at the jq-parse stage.
#
# $1 = target plugin root
set -euo pipefail
TARGET="${1:?usage: mutate.sh <target-plugin-root>}"
PJ="${TARGET}/.claude-plugin/plugin.json"
[[ -r "$PJ" ]] || { echo "ERROR: $PJ not readable" >&2; exit 2; }
# Append garbage that breaks parse; the file is no longer valid JSON.
printf '%s\n' '{ "bogus": "trailing-garbage", invalid' >> "$PJ"
