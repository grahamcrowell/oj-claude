#!/usr/bin/env bash
# legacy-reappear — re-introduce the legacy install tree (src/ + Makefile)
# inside the copied plugin root so C7 must fail with
# CATEGORY: legacy-install-tree-reappeared. Models the merge-conflict-
# resolution defect class BL-025-i.2 deleted these paths to prevent.
#
# $1 = target plugin root (a copy of oj-claude under a tempdir)
set -euo pipefail
TARGET="${1:?usage: mutate.sh <target-plugin-root>}"
mkdir -p "${TARGET}/src"
touch "${TARGET}/Makefile"
