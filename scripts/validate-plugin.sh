#!/usr/bin/env bash
#
# validate-plugin.sh — structural validation of the oj-claude plugin tree.
#
# SCOPE: Local-as-source-of-truth (BL-025-k F1). Runs structural checks
# C1..C6 against the plugin tree, then optionally invokes
# `claude plugin validate` as a final stage. Negative fixtures live in
# scripts/tests/fixtures/plugin-validate/<name>/ and are driven by
# plugin-validate-test.sh — this script validates the LIVE tree.
#
# Checks (cheap-and-structural first, per F6):
#   C1: .claude-plugin/plugin.json exists and parses as JSON.
#   C2: plugin.json has name/version/description; name == "oj"; semver.
#   C3: hooks/hooks.json exists, parses, every command path under
#       ${CLAUDE_PLUGIN_ROOT}/bin/ resolves to an executable file
#       relative to the plugin root.
#   C4: bin/oj-helper references the pinned-string contract by name
#       (drift canary — proof oj-helper imports lib/contracts.sh
#       instead of carrying an independent literal).
#   C5: CONDUCTOR.md exists at plugin root iff hooks.json has a
#       conductor-inject command.
#   C6: every skills/*/SKILL.md has parseable YAML frontmatter
#       (python3+yaml when available; header-match fallback; WARN
#       degrades gracefully — does NOT fail the run).
#   C7: legacy install tree (src/, Makefile) must not reappear at the
#       plugin root. Regression guard for the BL-025-i.2 deletion —
#       a future merge-conflict resolution that re-introduces either
#       path should fail the validator loudly.
#   Final (optional): `claude plugin validate <root>` if available.
#       For v0.0.1, warnings are TOLERATED (frontmatter audit deferred
#       to BL-025-l per F12); only non-zero exit fails unless --strict.
#
# Flags:
#   --no-claude   Skip the `claude plugin validate` final stage. Local
#                 dev convenience. NOT used in CI (workflow installs
#                 the CLI as a hard step).
#   --strict      Fail-on-warning from `claude plugin validate`. Reserved
#                 for BL-025-l marketplace-publish gate.
#
# Exit codes:
#   0  All checks passed.
#   1  One or more checks failed.
#   2  Driver error (no plugin tree found, etc.).
#
# Output format (BL-025-g/h structured-stderr pattern):
#   FAIL line on stderr:
#     CATEGORY: <kind> | FILE: <path> | LINE: <N> | DETAIL: <text>
#   PASS line on stdout:
#     PASS C<n>: <description>

set -euo pipefail

# ────────────────────────────────────────────────────────────────────
# Argument parsing
# ────────────────────────────────────────────────────────────────────
WITH_CLAUDE=1
STRICT=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-claude) WITH_CLAUDE=0; shift ;;
    --strict)    STRICT=1; shift ;;
    -h|--help)
      sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "ERROR: unknown flag: $1" >&2
      exit 2
      ;;
  esac
done

# ────────────────────────────────────────────────────────────────────
# Resolve plugin root
# ────────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

if [[ ! -d "${PLUGIN_ROOT}/.claude-plugin" ]]; then
  echo "ERROR: validate-plugin: no .claude-plugin/ directory at ${PLUGIN_ROOT}" >&2
  exit 2
fi

# ────────────────────────────────────────────────────────────────────
# Color setup (no color if stdout not a tty or NO_COLOR is set)
# ────────────────────────────────────────────────────────────────────
if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'; NC=$'\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; NC=''
fi

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

pass() {
  # $1 = check id (e.g., "C1")
  # $2 = description
  echo "${GREEN}PASS${NC} $1: $2"
  PASS_COUNT=$((PASS_COUNT + 1))
}

# Emit a structured FAIL line on stderr.
#   $1 = CATEGORY
#   $2 = FILE
#   $3 = LINE (use 0 if not applicable)
#   $4 = DETAIL
fail() {
  echo "${RED}FAIL${NC} CATEGORY: $1 | FILE: $2 | LINE: $3 | DETAIL: $4" >&2
  FAIL_COUNT=$((FAIL_COUNT + 1))
}

warn() {
  # $1 = check id, $2 = description
  echo "${YELLOW}WARN${NC} $1: $2"
  WARN_COUNT=$((WARN_COUNT + 1))
}

# ────────────────────────────────────────────────────────────────────
# Dependency probes
# ────────────────────────────────────────────────────────────────────
if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: validate-plugin: jq required (install via: brew install jq)" >&2
  exit 2
fi

# ────────────────────────────────────────────────────────────────────
# C1 — .claude-plugin/plugin.json exists and parses as JSON
# ────────────────────────────────────────────────────────────────────
check_c1_plugin_json_parses() {
  local f="${PLUGIN_ROOT}/.claude-plugin/plugin.json"
  if [[ ! -r "$f" ]]; then
    fail "plugin-manifest" ".claude-plugin/plugin.json" 0 "file missing or unreadable"
    return 1
  fi
  if ! jq -e . "$f" >/dev/null 2>&1; then
    fail "plugin-manifest" ".claude-plugin/plugin.json" 0 "invalid JSON (jq parse failed)"
    return 1
  fi
  pass "C1" ".claude-plugin/plugin.json exists and parses as JSON"
  return 0
}

# ────────────────────────────────────────────────────────────────────
# C2 — plugin.json fields: name="oj", version=semver, description set
# ────────────────────────────────────────────────────────────────────
check_c2_plugin_json_fields() {
  local f="${PLUGIN_ROOT}/.claude-plugin/plugin.json"
  if [[ ! -r "$f" ]] || ! jq -e . "$f" >/dev/null 2>&1; then
    # C1 already reported; skip silently
    return 1
  fi
  local rc=0
  local name version description
  name=$(jq -r '.name // empty' "$f")
  version=$(jq -r '.version // empty' "$f")
  description=$(jq -r '.description // empty' "$f")
  if [[ -z "$name" ]]; then
    fail "plugin-manifest" ".claude-plugin/plugin.json" 0 "missing required field: name"
    rc=1
  elif [[ "$name" != "oj" ]]; then
    fail "plugin-manifest" ".claude-plugin/plugin.json" 0 "name must be \"oj\" (got: $name)"
    rc=1
  fi
  if [[ -z "$version" ]]; then
    fail "plugin-manifest" ".claude-plugin/plugin.json" 0 "missing required field: version"
    rc=1
  elif ! [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?(\+[0-9A-Za-z.-]+)?$ ]]; then
    fail "plugin-manifest" ".claude-plugin/plugin.json" 0 "version not semver: $version"
    rc=1
  fi
  if [[ -z "$description" ]]; then
    fail "plugin-manifest" ".claude-plugin/plugin.json" 0 "missing required field: description"
    rc=1
  fi
  if [[ "$rc" -eq 0 ]]; then
    pass "C2" "plugin.json has name=\"oj\", semver version=$version, description set"
  fi
  return "$rc"
}

# ────────────────────────────────────────────────────────────────────
# C3 — hooks.json parses + every command resolves under bin/ + executable
# ────────────────────────────────────────────────────────────────────
check_c3_hooks_resolve() {
  local hooks_json="${PLUGIN_ROOT}/hooks/hooks.json"
  if [[ ! -r "$hooks_json" ]]; then
    fail "hooks-manifest" "hooks/hooks.json" 0 "file missing or unreadable"
    return 1
  fi
  if ! jq -e . "$hooks_json" >/dev/null 2>&1; then
    fail "hooks-manifest" "hooks/hooks.json" 0 "invalid JSON (jq parse failed)"
    return 1
  fi
  # Extract every .hooks[*].hooks[*].command across all event arrays.
  # Each command begins with `${CLAUDE_PLUGIN_ROOT}/bin/<binary> <subcmd...>`.
  local rc=0
  local commands
  commands=$(jq -r '
    [.hooks // {} | to_entries[] | .value[]?.hooks[]?.command // empty]
    | .[]
  ' "$hooks_json")

  if [[ -z "$commands" ]]; then
    fail "hooks-manifest" "hooks/hooks.json" 0 "no hook commands found"
    return 1
  fi

  local cmd binary_path binary_rel
  while IFS= read -r cmd; do
    [[ -z "$cmd" ]] && continue
    # Substitute ${CLAUDE_PLUGIN_ROOT} -> $PLUGIN_ROOT (mirror what the
    # plugin host does at hook-invocation time).
    local expanded="${cmd//\$\{CLAUDE_PLUGIN_ROOT\}/${PLUGIN_ROOT}}"
    # First token is the binary path; drop subcommand args.
    binary_path="${expanded%% *}"
    if [[ ! -e "$binary_path" ]]; then
      binary_rel="${binary_path#${PLUGIN_ROOT}/}"
      fail "hooks-manifest" "hooks/hooks.json" 0 "command path does not exist: $binary_rel (full: $cmd)"
      rc=1
      continue
    fi
    if [[ ! -x "$binary_path" ]]; then
      binary_rel="${binary_path#${PLUGIN_ROOT}/}"
      fail "hooks-manifest" "$binary_rel" 0 "command target is not executable (chmod +x missing?)"
      rc=1
      continue
    fi
    # Sanity: target must live under bin/ (defense in depth against
    # path-escape mistakes).
    case "$binary_path" in
      "${PLUGIN_ROOT}/bin/"*) ;;
      *)
        binary_rel="${binary_path#${PLUGIN_ROOT}/}"
        fail "hooks-manifest" "hooks/hooks.json" 0 "command target outside bin/: $binary_rel"
        rc=1
        ;;
    esac
  done <<< "$commands"

  if [[ "$rc" -eq 0 ]]; then
    pass "C3" "all hooks.json commands resolve to executable files under bin/"
  fi
  return "$rc"
}

# ────────────────────────────────────────────────────────────────────
# C4 — drift canary: bin/oj-helper must reference $OJ_STDERR_CONDUCTOR_MISSING
# ────────────────────────────────────────────────────────────────────
# Rationale (BL-025-k synthesis pre-mortem #1): catches the failure mode
# where contracts.sh is shipped but oj-helper still emits an independent
# hardcoded literal. The grep target is the VARIABLE REFERENCE — proof
# that oj-helper sources lib/contracts.sh and emits the centralized
# value, not a copy that could drift.
check_c4_pinned_string_drift() {
  local oj_helper="${PLUGIN_ROOT}/bin/oj-helper"
  local contracts="${PLUGIN_ROOT}/bin/lib/contracts.sh"
  if [[ ! -r "$oj_helper" ]]; then
    fail "pinned-string-drift" "bin/oj-helper" 0 "file missing or unreadable"
    return 1
  fi
  if [[ ! -r "$contracts" ]]; then
    fail "pinned-string-drift" "bin/lib/contracts.sh" 0 "contracts library missing"
    return 1
  fi
  # contracts.sh MUST export OJ_STDERR_CONDUCTOR_MISSING.
  if ! grep -qE '^[[:space:]]*readonly[[:space:]]+OJ_STDERR_CONDUCTOR_MISSING=' "$contracts"; then
    fail "pinned-string-drift" "bin/lib/contracts.sh" 0 "OJ_STDERR_CONDUCTOR_MISSING not declared readonly"
    return 1
  fi
  # Value-anchor: the constant's literal must match the canonical form.
  # Without this, the gate is tautological — both this validator and the
  # hook-test harness dereference the same variable, so a `readonly NAME=X`
  # with any X would pass. Anchoring the literal here turns the canary
  # into an actual contract on user-visible output.
  if ! grep -qF "OpenJunto: CONDUCTOR.md missing — manager protocol will not be injected this session" "$contracts"; then
    fail "pinned-string-drift" "bin/lib/contracts.sh" 27 "OJ_STDERR_CONDUCTOR_MISSING value drifted from canonical literal"
    return 1
  fi
  # bin/oj-helper MUST reference OJ_STDERR_CONDUCTOR_MISSING by name.
  # The grep is intentionally permissive on shell expansion form
  # (`${OJ_STDERR_CONDUCTOR_MISSING}` vs. `$OJ_STDERR_CONDUCTOR_MISSING`).
  if ! grep -qE '\$\{?OJ_STDERR_CONDUCTOR_MISSING\}?' "$oj_helper"; then
    fail "pinned-string-drift" "bin/oj-helper" 0 "no reference to \$OJ_STDERR_CONDUCTOR_MISSING (drift risk: hardcoded literal?)"
    return 1
  fi
  # bin/oj-helper MUST source lib/contracts.sh (so the variable resolves
  # at runtime). Match the common forms: `source lib/contracts.sh` or
  # `. lib/contracts.sh`, with optional path prefix.
  if ! grep -qE '(^|[[:space:]])(\.|source)[[:space:]]+[^[:space:]]*lib/contracts\.sh' "$oj_helper"; then
    fail "pinned-string-drift" "bin/oj-helper" 0 "does not source bin/lib/contracts.sh"
    return 1
  fi
  pass "C4" "bin/oj-helper sources lib/contracts.sh and references \$OJ_STDERR_CONDUCTOR_MISSING (drift canary intact)"
  return 0
}

# ────────────────────────────────────────────────────────────────────
# C5 — CONDUCTOR.md present iff hooks.json wires conductor-inject
# ────────────────────────────────────────────────────────────────────
check_c5_conductor_consistency() {
  local hooks_json="${PLUGIN_ROOT}/hooks/hooks.json"
  local conductor_md="${PLUGIN_ROOT}/CONDUCTOR.md"
  if [[ ! -r "$hooks_json" ]] || ! jq -e . "$hooks_json" >/dev/null 2>&1; then
    # C3 already reported; skip silently
    return 1
  fi
  local has_conductor_inject="no"
  if jq -r '.hooks // {} | to_entries[] | .value[]?.hooks[]?.command // empty' "$hooks_json" \
       | grep -qF "conductor-inject"; then
    has_conductor_inject="yes"
  fi
  local conductor_present="no"
  [[ -r "$conductor_md" ]] && conductor_present="yes"

  if [[ "$has_conductor_inject" = "yes" && "$conductor_present" = "no" ]]; then
    fail "conductor-consistency" "CONDUCTOR.md" 0 "hooks.json wires conductor-inject but CONDUCTOR.md is missing at plugin root"
    return 1
  fi
  if [[ "$has_conductor_inject" = "no" && "$conductor_present" = "yes" ]]; then
    # Soft inconsistency — file present but no hook. Don't fail; surface
    # as a WARN. An adopter may have disabled the manager protocol by
    # editing hooks.json without removing CONDUCTOR.md.
    warn "C5" "CONDUCTOR.md present but hooks.json does not wire conductor-inject (intentional?)"
    return 0
  fi
  pass "C5" "CONDUCTOR.md presence matches hooks.json conductor-inject wiring (both=$has_conductor_inject)"
  return 0
}

# ────────────────────────────────────────────────────────────────────
# C6 — every skills/*/SKILL.md has parseable YAML frontmatter
# ────────────────────────────────────────────────────────────────────
# Uses python3+yaml when available (full parse). Falls back to a
# header-match (look for ^---\n) when python3 or PyYAML is missing.
# Frontmatter parse failures are WARN, not FAIL, per F12 (warnings
# tolerated for v0.0.1; marketplace-publish gate is BL-025-l).
check_c6_skill_frontmatter() {
  local skills_dir="${PLUGIN_ROOT}/skills"
  if [[ ! -d "$skills_dir" ]]; then
    # Plugin without skills is legal — no skills, nothing to validate.
    pass "C6" "no skills/ directory (skipping frontmatter check)"
    return 0
  fi

  local have_python_yaml=0
  if command -v python3 >/dev/null 2>&1 \
     && python3 -c 'import yaml' >/dev/null 2>&1; then
    have_python_yaml=1
  fi

  local found=0
  local skill_md skill_name
  for skill_md in "$skills_dir"/*/SKILL.md; do
    [[ -r "$skill_md" ]] || continue
    found=$((found + 1))
    skill_name=$(basename "$(dirname "$skill_md")")
    if [[ "$have_python_yaml" -eq 1 ]]; then
      local parse_err
      parse_err=$(python3 -c '
import sys, yaml
p = sys.argv[1]
with open(p, "r", encoding="utf-8") as f:
  text = f.read()
if not text.startswith("---"):
  print("no leading --- delimiter")
  sys.exit(1)
# Extract between the first two --- lines.
parts = text.split("---", 2)
if len(parts) < 3:
  print("missing closing --- delimiter")
  sys.exit(1)
try:
  data = yaml.safe_load(parts[1])
except yaml.YAMLError as e:
  print(f"yaml parse error: {e}")
  sys.exit(1)
if not isinstance(data, dict):
  print("frontmatter is not a YAML mapping")
  sys.exit(1)
if "description" not in data:
  print("frontmatter missing required key: description")
  sys.exit(1)
' "$skill_md" 2>&1) || {
        warn "C6" "skills/$skill_name/SKILL.md frontmatter: $parse_err"
        continue
      }
    else
      # Fallback: header match only.
      if ! head -1 "$skill_md" | grep -qE '^---[[:space:]]*$'; then
        warn "C6" "skills/$skill_name/SKILL.md: no leading --- delimiter (python3+yaml unavailable, skipped full parse)"
      fi
    fi
  done

  if [[ "$found" -eq 0 ]]; then
    pass "C6" "skills/ present but contains no SKILL.md files"
  else
    if [[ "$have_python_yaml" -eq 1 ]]; then
      pass "C6" "all $found SKILL.md frontmatter blocks parse as YAML (python3+yaml)"
    else
      pass "C6" "all $found SKILL.md files have leading --- delimiter (python3+yaml not installed; header-match only)"
    fi
  fi
  return 0
}

# ────────────────────────────────────────────────────────────────────
# C7 — legacy install tree (src/, Makefile) must not reappear
# ────────────────────────────────────────────────────────────────────
# Regression guard for BL-025-i.2: oj-claude/src/ and oj-claude/Makefile
# were deleted when the Makefile install path was retired. A merge
# conflict resolved by checking out an old revision could re-introduce
# either path; this check fails the validator if that happens.
check_c7_no_legacy_install_tree() {
  local rc=0
  if [[ -e "${PLUGIN_ROOT}/src" ]]; then
    fail "legacy-install-tree-reappeared" "src" 0 "BL-025-i.2 deleted this; reappearance suggests revert mishap"
    rc=1
  fi
  if [[ -e "${PLUGIN_ROOT}/Makefile" ]]; then
    fail "legacy-install-tree-reappeared" "Makefile" 0 "BL-025-i.2 deleted this; reappearance suggests revert mishap"
    rc=1
  fi
  if [[ "$rc" -eq 0 ]]; then
    pass "C7" "legacy install tree (src/, Makefile) absent at plugin root"
  fi
  return "$rc"
}

# ────────────────────────────────────────────────────────────────────
# Final stage — claude plugin validate (CLI), warnings tolerated v0.0.1
# ────────────────────────────────────────────────────────────────────
check_claude_plugin_validate() {
  if [[ "${WITH_CLAUDE}" -eq 0 ]]; then
    echo "${YELLOW}INFO${NC} claude plugin validate: skipped (--no-claude)"
    return 0
  fi
  if ! command -v claude >/dev/null 2>&1; then
    # CI invokes without --no-claude; absence here is a hard failure
    # so the workflow detects a broken/unpinned install.
    fail "claude-cli-missing" "(system)" 0 "claude CLI not on PATH; either install @anthropic-ai/claude-code or pass --no-claude for local-dev structural-only run"
    return 1
  fi

  local out_file="${TMPDIR:-/tmp}/validate-plugin.claude.$$.stdout"
  local err_file="${TMPDIR:-/tmp}/validate-plugin.claude.$$.stderr"
  trap 'rm -f "$out_file" "$err_file"' RETURN
  local rc=0
  claude plugin validate "${PLUGIN_ROOT}" >"$out_file" 2>"$err_file" || rc=$?

  local warning_count
  warning_count=$(grep -c "Found 1 warning" "$out_file" 2>/dev/null || true)
  warning_count="${warning_count:-0}"

  if [[ "$rc" -ne 0 ]]; then
    fail "claude-plugin-validate" "(plugin tree)" 0 "claude plugin validate exited $rc (stderr head: $(head -1 "$err_file" 2>/dev/null))"
    return 1
  fi

  if [[ "${STRICT}" -eq 1 && "$warning_count" -gt 0 ]]; then
    fail "claude-plugin-validate-strict" "(plugin tree)" 0 "claude plugin validate produced $warning_count warning(s) and --strict was passed"
    return 1
  fi

  pass "Final" "claude plugin validate exited 0 ($warning_count warning(s) — tolerated for v0.0.1)"
  return 0
}

# ────────────────────────────────────────────────────────────────────
# Orchestrate
# ────────────────────────────────────────────────────────────────────
echo "${YELLOW}INFO${NC} validate-plugin: tree=${PLUGIN_ROOT}"
echo

# `|| true` keeps individual check failures from aborting the run; each
# check increments FAIL_COUNT internally. We tally + decide at the end.
check_c1_plugin_json_parses        || true
check_c2_plugin_json_fields        || true
check_c3_hooks_resolve             || true
check_c4_pinned_string_drift       || true
check_c5_conductor_consistency     || true
check_c6_skill_frontmatter         || true
check_c7_no_legacy_install_tree    || true
check_claude_plugin_validate       || true

echo
echo "================================"
if [[ "$FAIL_COUNT" -eq 0 ]]; then
  echo "${GREEN}PASS${NC} validate-plugin: ${PASS_COUNT} check(s) passed, ${WARN_COUNT} warning(s)"
  echo "================================"
  exit 0
fi
echo "${RED}FAIL${NC} validate-plugin: ${FAIL_COUNT} check(s) failed (${PASS_COUNT} passed, ${WARN_COUNT} warning(s))"
echo "================================"
exit 1
