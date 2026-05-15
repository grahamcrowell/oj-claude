#!/usr/bin/env bash
# non-exec-bin — strip the executable bit from bin/oj-helper so the C3
# hooks-manifest check reports the target is not executable.
#
# Per F9 (synthesis): claude plugin validate likely does NOT flag this;
# the structural check owns the assertion.
#
# $1 = target plugin root
set -euo pipefail
TARGET="${1:?usage: mutate.sh <target-plugin-root>}"
HELPER="${TARGET}/bin/oj-helper"
[[ -e "$HELPER" ]] || { echo "ERROR: $HELPER not found" >&2; exit 2; }
chmod -x "$HELPER"
