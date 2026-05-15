#!/usr/bin/env bash
#
# plugin-validate-test.sh — fixture harness for scripts/validate-plugin.sh.
#
# SCOPE: Drive the structural validator against the live plugin tree
# (positive) and against 7 negative fixtures + 1 drift FALSIFIER.
# Negative fixtures live in scripts/tests/fixtures/plugin-validate/<name>/
# each with mutate.sh + expected.txt.
#
# Scenarios:
#   P1  positive: live oj-claude/ tree → exit 0, no FAIL lines.
#   N1  missing-name           → exit 1, FAIL contains CATEGORY: plugin-manifest
#   N2  bad-json                → exit 1, FAIL contains CATEGORY: plugin-manifest
#   N3  non-exec-bin            → exit 1, FAIL contains "not executable"
#                                  (NOT detected by claude plugin validate per F9)
#   N4  broken-conductor-stderr → exit 1, FAIL contains CATEGORY: conductor-consistency
#   N5  stale-hook-path         → exit 1, FAIL contains "command path does not exist"
#   N6  contract-value-drift   → exit 1, FAIL contains CATEGORY: pinned-string-drift
#                                  (BL-025-k Phase 4: defeats the tautological
#                                  variable-only canary by mutating contracts.sh
#                                  itself; the value-anchor grep must catch it.)
#   N7  legacy-reappear         → exit 1, FAIL contains CATEGORY: legacy-install-tree-reappeared
#                                  (BL-025-i.2 regression guard: re-plant src/ + Makefile
#                                  at the plugin root and assert C7 fires.)
#   N8  drift FALSIFIER (pre-mortem #1): sed-mutate bin/oj-helper to drop
#       the OJ_STDERR_CONDUCTOR_MISSING variable reference; assert C4
#       fires with CATEGORY: pinned-string-drift.
#
# Test isolation: every scenario builds a private tempdir, copies the
# subset of the plugin tree that the validator inspects, applies the
# fixture mutation, then runs validate-plugin.sh with --no-claude (so
# the harness does not depend on `claude` being installed locally).
#
# Cleanup: single-arg EXIT trap per the 2026-05-08 BL-025-e.2 lesson:
#   `trap 'rm -rf "$TMPROOT"' EXIT`
#
# Exit codes:
#   0 — all scenarios pass
#   1 — at least one scenario failed
#   2 — driver error (validate-plugin.sh missing, etc.)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
VALIDATOR="${PLUGIN_ROOT}/scripts/validate-plugin.sh"
FIXTURES_DIR="${SCRIPT_DIR}/fixtures/plugin-validate"

if [[ -t 1 ]]; then
  RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'; CYAN=$'\033[0;36m'; NC=$'\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; CYAN=''; NC=''
fi

[[ -x "${VALIDATOR}" ]] || { echo "${RED}ERROR${NC} validator not executable: ${VALIDATOR}" >&2; exit 2; }
command -v jq >/dev/null 2>&1 || { echo "${RED}ERROR${NC} jq required to run this harness." >&2; exit 2; }

PASS_COUNT=0
FAIL_COUNT=0

assert_one() {
  local label="$1"; local cond="$2"; local detail="${3:-}"
  if [[ "$cond" = "ok" ]]; then
    echo "${GREEN}PASS${NC} ${label}"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    echo "${RED}FAIL${NC} ${label}"
    [[ -n "$detail" ]] && echo "${CYAN}      ${detail}${NC}"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi
}

# Copy the subset of the plugin tree that validate-plugin.sh inspects.
# Avoids hauling .git, Makefile, src/, generation-logs/, agents/ (large)
# into every fixture run. This is also F11-aligned: validator is
# insensitive to legacy `src/` + `Makefile`, so they are not needed.
#
# We deliberately INCLUDE skills/ in full (C6 walks every SKILL.md).
#
#   $1 = destination dir
copy_plugin_subset() {
  local dest="$1"
  mkdir -p "${dest}/.claude-plugin" "${dest}/bin/lib" "${dest}/hooks" "${dest}/skills"
  cp "${PLUGIN_ROOT}/.claude-plugin/plugin.json"   "${dest}/.claude-plugin/plugin.json"
  cp "${PLUGIN_ROOT}/hooks/hooks.json"             "${dest}/hooks/hooks.json"
  cp "${PLUGIN_ROOT}/bin/oj-helper"                "${dest}/bin/oj-helper"
  cp "${PLUGIN_ROOT}/bin/lib/contracts.sh"         "${dest}/bin/lib/contracts.sh"
  chmod +x "${dest}/bin/oj-helper"
  if [[ -r "${PLUGIN_ROOT}/CONDUCTOR.md" ]]; then
    cp "${PLUGIN_ROOT}/CONDUCTOR.md"               "${dest}/CONDUCTOR.md"
  fi
  if [[ -r "${PLUGIN_ROOT}/VERSION" ]]; then
    cp "${PLUGIN_ROOT}/VERSION"                    "${dest}/VERSION"
  fi
  # Copy each skill directory.
  local skill
  if compgen -G "${PLUGIN_ROOT}/skills/*" > /dev/null; then
    for skill in "${PLUGIN_ROOT}"/skills/*/; do
      [[ -d "$skill" ]] || continue
      cp -R "$skill" "${dest}/skills/"
    done
  fi
}

# Invoke validate-plugin.sh against a copied tree. Sets the validator's
# resolved PLUGIN_ROOT by placing it at $dest/scripts/validate-plugin.sh
# (validator computes plugin root as ../ relative to its script dir).
#
#   $1 = copied plugin root
#   $2 = output file for stdout
#   $3 = output file for stderr
#   $4..N = extra args to validator (default: --no-claude)
run_validator_in_copy() {
  local copied_root="$1"; shift
  local out_file="$1"; shift
  local err_file="$1"; shift
  mkdir -p "${copied_root}/scripts"
  cp "${VALIDATOR}" "${copied_root}/scripts/validate-plugin.sh"
  chmod +x "${copied_root}/scripts/validate-plugin.sh"
  local rc=0
  bash "${copied_root}/scripts/validate-plugin.sh" "$@" \
       >"$out_file" 2>"$err_file" || rc=$?
  echo "$rc"
}

# ────────────────────────────────────────────────────────────────────
# P1 — positive: live oj-claude/ tree → exit 0, no FAIL lines
# ────────────────────────────────────────────────────────────────────
scenario_p1_positive() {
  local T; T=$(mktemp -d -t oj-validate-p1-XXXXXX)
  trap 'rm -rf "$T"' EXIT

  copy_plugin_subset "$T/plugin"
  local rc
  rc=$(run_validator_in_copy "$T/plugin" "$T/stdout" "$T/stderr" --no-claude)

  if [[ "$rc" = "0" ]]; then
    assert_one "P1 positive: validator exits 0" "ok"
  else
    assert_one "P1 positive: validator exits 0" "fail" "rc=$rc stderr=$(cat "$T/stderr")"
    rm -rf "$T"; trap - EXIT; return
  fi
  if ! grep -q "^FAIL\| FAIL " "$T/stdout" "$T/stderr" 2>/dev/null; then
    assert_one "P1 positive: no FAIL lines emitted" "ok"
  else
    assert_one "P1 positive: no FAIL lines emitted" "fail" "stdout/stderr contained FAIL"
  fi

  # All structural checks (C1..C7) should be marked PASS.
  local missing=""
  local cid
  for cid in C1 C2 C3 C4 C5 C6 C7; do
    if ! grep -q "PASS $cid:" "$T/stdout"; then
      missing="${missing}${cid} "
    fi
  done
  if [[ -z "$missing" ]]; then
    assert_one "P1 positive: all structural checks (C1..C7) emit PASS" "ok"
  else
    assert_one "P1 positive: all structural checks (C1..C7) emit PASS" "fail" "missing=$missing stdout=$(cat "$T/stdout")"
  fi

  rm -rf "$T"; trap - EXIT
}

# ────────────────────────────────────────────────────────────────────
# Negative fixture driver.
# $1 = fixture name (subdir of FIXTURES_DIR)
# Reads $FIXTURES_DIR/<name>/expected.txt as the substring to grep in
# the combined validator output (stdout + stderr) on failure.
# ────────────────────────────────────────────────────────────────────
scenario_negative_fixture() {
  local name="$1"
  local fdir="${FIXTURES_DIR}/${name}"
  if [[ ! -d "$fdir" ]]; then
    assert_one "N: $name: fixture dir present" "fail" "missing: $fdir"
    return
  fi
  if [[ ! -x "${fdir}/mutate.sh" ]]; then
    assert_one "N: $name: mutate.sh executable" "fail" "missing or non-exec: ${fdir}/mutate.sh"
    return
  fi
  if [[ ! -r "${fdir}/expected.txt" ]]; then
    assert_one "N: $name: expected.txt readable" "fail" "missing: ${fdir}/expected.txt"
    return
  fi

  local expected
  expected=$(head -1 "${fdir}/expected.txt" | sed -E 's/[[:space:]]+$//')

  local T; T=$(mktemp -d -t "oj-validate-${name}-XXXXXX")
  trap 'rm -rf "$T"' EXIT

  copy_plugin_subset "$T/plugin"
  bash "${fdir}/mutate.sh" "$T/plugin"

  local rc
  rc=$(run_validator_in_copy "$T/plugin" "$T/stdout" "$T/stderr" --no-claude)

  if [[ "$rc" != "0" ]]; then
    assert_one "N: $name: validator exits non-zero after mutation" "ok"
  else
    assert_one "N: $name: validator exits non-zero after mutation" "fail" "rc=0 (expected non-zero); stdout=$(cat "$T/stdout") stderr=$(cat "$T/stderr")"
    rm -rf "$T"; trap - EXIT; return
  fi

  if grep -qF "$expected" "$T/stdout" "$T/stderr" 2>/dev/null; then
    assert_one "N: $name: FAIL output contains expected substring [$expected]" "ok"
  else
    assert_one "N: $name: FAIL output contains expected substring [$expected]" "fail" "stdout=$(cat "$T/stdout") stderr=$(cat "$T/stderr")"
  fi

  rm -rf "$T"; trap - EXIT
}

# ────────────────────────────────────────────────────────────────────
# N6 — drift FALSIFIER (pre-mortem #1): mutate bin/oj-helper to drop
# the OJ_STDERR_CONDUCTOR_MISSING reference. C4 must fire with
# CATEGORY: pinned-string-drift.
# ────────────────────────────────────────────────────────────────────
scenario_n6_drift_falsifier() {
  local T; T=$(mktemp -d -t oj-validate-n6-XXXXXX)
  trap 'rm -rf "$T"' EXIT

  copy_plugin_subset "$T/plugin"

  # Mutate bin/oj-helper: replace the variable reference with an
  # independent literal that has subtly different text. This is the
  # exact failure mode pre-mortem #1 names — drift introduced by a
  # well-meaning edit that bypasses contracts.sh.
  local helper="$T/plugin/bin/oj-helper"
  # Use sed -i.bak portable form (macOS BSD sed requires the suffix arg).
  sed -i.bak \
      -e 's|"${OJ_STDERR_CONDUCTOR_MISSING}"|"OpenJunto: CONDUCTOR.md absent (drift!)"|g' \
      "$helper"
  rm -f "${helper}.bak"

  # Confirm mutation took effect (defensive — fails the FALSIFIER if not).
  # We check for the variable REFERENCE form (with $ prefix); a stale
  # bare-name mention in a comment is fine and not what C4 targets.
  if grep -qE '\$\{?OJ_STDERR_CONDUCTOR_MISSING\}?' "$helper"; then
    assert_one "N6 drift FALSIFIER: mutation removed variable reference" "fail" "reference still present in helper"
    rm -rf "$T"; trap - EXIT; return
  fi
  assert_one "N6 drift FALSIFIER: mutation removed variable reference" "ok"

  local rc
  rc=$(run_validator_in_copy "$T/plugin" "$T/stdout" "$T/stderr" --no-claude)

  if [[ "$rc" != "0" ]]; then
    assert_one "N6 drift FALSIFIER: validator exits non-zero" "ok"
  else
    assert_one "N6 drift FALSIFIER: validator exits non-zero" "fail" "rc=0 stdout=$(cat "$T/stdout") stderr=$(cat "$T/stderr")"
    rm -rf "$T"; trap - EXIT; return
  fi

  if grep -qF "CATEGORY: pinned-string-drift" "$T/stdout" "$T/stderr" 2>/dev/null; then
    assert_one "N6 drift FALSIFIER: C4 fires with pinned-string-drift category" "ok"
  else
    assert_one "N6 drift FALSIFIER: C4 fires with pinned-string-drift category" "fail" "stdout=$(cat "$T/stdout") stderr=$(cat "$T/stderr")"
  fi

  rm -rf "$T"; trap - EXIT
}

echo "${YELLOW}[INFO]${NC} plugin-validate-test"
echo "${YELLOW}[INFO]${NC} validator: ${VALIDATOR}"
echo "${YELLOW}[INFO]${NC} fixtures:  ${FIXTURES_DIR}"
echo

scenario_p1_positive
scenario_negative_fixture missing-name
scenario_negative_fixture bad-json
scenario_negative_fixture non-exec-bin
scenario_negative_fixture broken-conductor-stderr
scenario_negative_fixture stale-hook-path
scenario_negative_fixture contract-value-drift
scenario_negative_fixture legacy-reappear
scenario_n6_drift_falsifier

echo
echo "================================"
TOTAL=$((PASS_COUNT + FAIL_COUNT))
if [[ "${FAIL_COUNT}" -eq 0 ]]; then
  echo "${GREEN}PASS${NC} plugin-validate-test: ${PASS_COUNT}/${TOTAL}"
  echo "================================"
  exit 0
fi
echo "${RED}FAIL${NC} plugin-validate-test: ${FAIL_COUNT}/${TOTAL} assertion(s) failed"
echo "================================"
exit 1
