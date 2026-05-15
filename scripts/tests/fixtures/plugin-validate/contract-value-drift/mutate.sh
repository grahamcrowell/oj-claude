#!/usr/bin/env bash
# contract-value-drift — mutate bin/lib/contracts.sh so the canonical
# literal of OJ_STDERR_CONDUCTOR_MISSING drifts to a different string.
#
# Defeats the original tautological C4 gate (both validator and hook-test
# dereferenced the same variable, so the comparison was x == x regardless
# of x). With the value-anchor grep added in BL-025-k Phase 4, C4 must
# now FAIL with CATEGORY: pinned-string-drift when the literal drifts.
#
# Exit non-zero (not 0) if the canonical literal is not present in
# contracts.sh — so a future refactor that renames or relocates the
# constant breaks this fixture LOUDLY rather than silently passing.
#
# $1 = target plugin root (a copy of oj-claude under a tempdir)
set -euo pipefail
TARGET="${1:?usage: mutate.sh <target-plugin-root>}"
CONTRACTS="${TARGET}/bin/lib/contracts.sh"
[[ -r "$CONTRACTS" ]] || { echo "ERROR: $CONTRACTS not readable" >&2; exit 2; }

CANONICAL="OpenJunto: CONDUCTOR.md missing — manager protocol will not be injected this session"
DRIFTED="OpenJunto: CONDUCTOR.md GONE WRONG — totally different stderr now"

# Defensive: refuse to mutate if the canonical literal is absent. This
# makes the fixture self-validating against future contracts.sh refactors.
if ! grep -qF "$CANONICAL" "$CONTRACTS"; then
  echo "ERROR: canonical literal not found in $CONTRACTS — fixture is stale; update mutate.sh after contracts.sh refactor" >&2
  exit 3
fi

# Portable in-place sed (macOS BSD requires the suffix arg). Use a pipe
# delimiter because the literal contains '/' and we want to avoid escaping.
sed -i.bak "s|${CANONICAL}|${DRIFTED}|" "$CONTRACTS"
rm -f "${CONTRACTS}.bak"

# Confirm the mutation took effect — sanity check against typo regressions
# in the sed expression itself.
if grep -qF "$CANONICAL" "$CONTRACTS"; then
  echo "ERROR: sed mutation did not replace canonical literal" >&2
  exit 4
fi
