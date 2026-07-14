#!/usr/bin/env bash
#
# v0.1.0-regression-test.sh — statically verifiable guards for the v0.1.0
# release (commit f91e124) and traceability for the assessment's section-4
# recommendations.
#
# Companion doc: docs/test-plans/v0.1.0-test-plan.md
#   - Tier B (mechanical, change-specific)  -> implemented here (T-B*)
#   - Tier D (recommendation traceability)  -> implemented here (T-D*)
#   - Tier A (existing harnesses) and Tier C (live-session runtime) are NOT
#     covered here; run scripts/validate-plugin.sh + scripts/tests/*.sh for A,
#     and drive a live session for C. Tier C tests print as SKIP below.
#
# This script runs entirely against the checked-out plugin tree — no `claude`
# CLI, no network, no live session. It is safe in pre-commit / CI.
#
# KNOWN GAP MECHANISM: assert_known_gap FAILs by default (keeps a recommendation
# gap loud) and WARNs under OJ_ALLOW_KNOWN_GAPS=1 (so CI can stay green while a
# follow-up is tracked). As of the senior-sre.md fix, there are NO open known
# gaps — the mechanism is retained for future partial-implementation tracking.
#
# Exit codes:
#   0 — all assertions pass (known gaps WARNed if OJ_ALLOW_KNOWN_GAPS=1)
#   1 — at least one assertion failed
#   2 — driver error (wrong tree, missing dependency)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

if [[ -t 1 ]]; then
  RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'; CYAN=$'\033[0;36m'; NC=$'\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; CYAN=''; NC=''
fi

command -v jq      >/dev/null 2>&1 || { echo "${RED}ERROR${NC} jq required."      >&2; exit 2; }
command -v python3 >/dev/null 2>&1 || { echo "${RED}ERROR${NC} python3 required." >&2; exit 2; }
[[ -f "${PLUGIN_ROOT}/CONDUCTOR.md" ]] || { echo "${RED}ERROR${NC} not a plugin tree: ${PLUGIN_ROOT}" >&2; exit 2; }

PASS_COUNT=0; FAIL_COUNT=0; WARN_COUNT=0; SKIP_COUNT=0
ALLOW_GAPS="${OJ_ALLOW_KNOWN_GAPS:-0}"

pass() { echo "${GREEN}PASS${NC} $1"; PASS_COUNT=$((PASS_COUNT+1)); }
skip() { echo "${CYAN}SKIP${NC} $1"; SKIP_COUNT=$((SKIP_COUNT+1)); }
fail() { echo "${RED}FAIL${NC} $1"; [[ -n "${2:-}" ]] && echo "${CYAN}      $2${NC}"; FAIL_COUNT=$((FAIL_COUNT+1)); }

# assert LABEL COND [DETAIL] — COND is "ok" to pass, anything else to fail.
assert() { if [[ "$2" == "ok" ]]; then pass "$1"; else fail "$1" "${3:-}"; fi; }

# assert_known_gap LABEL COND [DETAIL] — a documented recommendation gap. FAILs
# by default (keeps the gap loud); WARNs when OJ_ALLOW_KNOWN_GAPS=1.
assert_known_gap() {
  if [[ "$2" == "ok" ]]; then pass "$1"; return; fi
  if [[ "${ALLOW_GAPS}" == "1" ]]; then
    echo "${YELLOW}WARN${NC} $1 (known v0.1.0 gap)"; [[ -n "${3:-}" ]] && echo "${CYAN}      $3${NC}"; WARN_COUNT=$((WARN_COUNT+1))
  else
    fail "$1" "${3:-} [set OJ_ALLOW_KNOWN_GAPS=1 to downgrade to WARN]"
  fi
}

# grep helpers returning "ok"/"no"
has()  { grep -q  -- "$2" "$1" 2>/dev/null && echo ok || echo no; }   # has FILE PATTERN
hasF() { grep -qF -- "$2" "$1" 2>/dev/null && echo ok || echo no; }   # fixed-string
lacks(){ grep -q  -- "$2" "$1" 2>/dev/null && echo no || echo ok; }
lacksF(){ grep -qF -- "$2" "$1" 2>/dev/null && echo no || echo ok; }

cd "${PLUGIN_ROOT}"

# ── inject-profile invocation helper ──────────────────────────────────
# invoke_inject <plugin_dir> <profile_name>  -> prints additionalContext;
# sets global INJECT_RC. Reproduces the SubagentStart hook contract used by
# plugin-e2e-test.sh scenario T2 (marker in a compact JSONL transcript line).
INJECT_RC=0
invoke_inject() {
  local plugin_dir="$1" profile="$2"
  local TD; TD=$(mktemp -d -t oj-reg-XXXXXX)
  local agent_id="reg-${profile}"
  local transcript_path="${TD}/session.jsonl"
  local subagent_transcript="${TD}/session/subagents/agent-${agent_id}.jsonl"
  mkdir -p "${TD}/session/subagents" "${TD}/home" "${TD}/data" "${TD}/xdg"
  local marker="<!-- oj-expert: ${profile} -->"
  jq -cn --arg content "$(printf '%s\n\nnoop for the regression test.\n' "${marker}")" \
     '{message: {role: "user", content: $content}}' > "${subagent_transcript}"
  local hook_input
  hook_input=$(jq -cn --arg a general-purpose --arg t "${transcript_path}" --arg id "${agent_id}" \
     '{agent_type: $a, transcript_path: $t, agent_id: $id}')
  local out
  set +e
  out=$(HOME="${TD}/home" CLAUDE_PLUGIN_ROOT="${plugin_dir}" CLAUDE_PLUGIN_DATA="${TD}/data" \
        XDG_CONFIG_HOME="${TD}/xdg" "${plugin_dir}/bin/oj-helper" inject-profile \
        2>/dev/null <<<"${hook_input}")
  INJECT_RC=$?
  set -e
  rm -rf "${TD}"
  printf '%s' "${out}"
}

echo "== oj-claude v0.1.0 regression + traceability =="
echo "   tree: ${PLUGIN_ROOT}"
echo

# ══════════════════════════════════════════════════════════════════════
# Tier B — mechanical assertions (change-specific)
# ══════════════════════════════════════════════════════════════════════

echo "-- C1: CONDUCTOR slim + execution-protocol split --"
assert "T-B1.1 reference/execution-protocol.md exists and non-empty" \
  "$([[ -s reference/execution-protocol.md ]] && echo ok || echo no)"
assert "T-B1.2 CONDUCTOR.md carries the execution-protocol load pointer" \
  "$(has CONDUCTOR.md 'reference/execution-protocol.md')"
for h in 'Delegation Boundary' 'Triage Requirement' 'Two-Dimensional Triage' \
         'Stakeholder Perspectives' 'Tier Overview and Just-in-Time Loading'; do
  assert "T-B1.2 CONDUCTOR core retains header: ${h}" "$(hasF CONDUCTOR.md "${h}")"
done
# T-B1.3 injected byte budget (measure additionalContext, the real payload)
CI_CTX=$(HOME="$(mktemp -d)" CLAUDE_PLUGIN_ROOT="${PLUGIN_ROOT}" \
  "${PLUGIN_ROOT}/bin/oj-helper" conductor-inject 2>/dev/null \
  | jq -r '.hookSpecificOutput.additionalContext')
CI_BYTES=$(printf '%s' "${CI_CTX}" | wc -c | tr -d ' ')
assert "T-B1.3 conductor-inject payload < 15000 bytes (got ${CI_BYTES}; v0.0.11 ~20.6KB)" \
  "$([[ "${CI_BYTES}" -gt 0 && "${CI_BYTES}" -lt 15000 ]] && echo ok || echo no)" \
  "additionalContext measured at ${CI_BYTES} bytes"

echo "-- C2: Trivial (tier-0) fast-path --"
assert "T-B2.1 CONDUCTOR defines Trivial tier-0 with zero mandatory stakeholders" \
  "$(hasF CONDUCTOR.md 'zero mandatory stakeholders')"
assert "T-B2.2 mandatory pair scoped to Simple and above" \
  "$(hasF CONDUCTOR.md 'Simple and above')"
assert "T-B2.2 mandatory pair names Product Manager + Distinguished Engineer" \
  "$(grep -q 'Product Manager' CONDUCTOR.md && grep -q 'Distinguished Engineer' CONDUCTOR.md && echo ok || echo no)"

echo "-- C3: reviewer scope --"
for f in skills/cycle/SKILL.md skills/run-task/SKILL.md reference/execution-protocol.md; do
  assert "T-B3.1 '${f}' says 'no material concerns' acceptable" "$(hasF "${f}" 'no material concerns')"
done
assert "T-B3.1 FAILURE MODES TESTED retained (cycle skill)" "$(hasF skills/cycle/SKILL.md 'FAILURE MODES TESTED')"
assert "T-B3.2 execution-protocol scopes reviewer to correctness/requirements" \
  "$(hasF reference/execution-protocol.md 'correctness or requirements')"

echo "-- C4: full-profile frontmatter --"
PROF_COUNT=$(ls agents/senior-*.md 2>/dev/null | wc -l | tr -d ' ')
assert "T-B4.2 agents/ has exactly 16 full profiles (got ${PROF_COUNT})" \
  "$([[ "${PROF_COUNT}" -eq 16 ]] && echo ok || echo no)"
FM_BAD=$(python3 - <<'PY'
import glob, os, yaml
bad = []
for p in sorted(glob.glob("agents/senior-*.md")):
    stem = os.path.basename(p)[:-3]
    with open(p) as f:
        text = f.read()
    if not text.startswith("---\n"):
        bad.append(stem + "(no-frontmatter)"); continue
    block = text[4:].split("\n---", 1)[0]
    try:
        d = yaml.safe_load(block) or {}
    except Exception:
        bad.append(stem + "(unparseable)"); continue
    if sorted(d.keys()) != ["description", "name"]:
        bad.append(stem + "(keys=%s)" % sorted(d.keys())); continue
    if d.get("name") != stem:
        bad.append(stem + "(name=%r)" % d.get("name")); continue
    if not str(d.get("description", "")).strip():
        bad.append(stem + "(empty-desc)")
print(" ".join(bad))
PY
)
assert "T-B4.1 all 16 profiles have two-key {name,description} frontmatter, name==stem" \
  "$([[ -z "${FM_BAD}" ]] && echo ok || echo no)" "offenders: ${FM_BAD}"

echo "-- C5: registration hygiene + inject-profile --"
assert "T-B5.1 agents/_preamble.md removed"  "$([[ ! -e agents/_preamble.md ]] && echo ok || echo no)"
assert "T-B5.1 agents/index.md removed"      "$([[ ! -e agents/index.md ]] && echo ok || echo no)"
assert "T-B5.1 agents/compact/ removed"      "$([[ ! -d agents/compact ]] && echo ok || echo no)"
assert "T-B5.1 reference/expert-preamble.md present" "$([[ -s reference/expert-preamble.md ]] && echo ok || echo no)"
assert "T-B5.1 reference/expert-index.md present"    "$([[ -s reference/expert-index.md ]] && echo ok || echo no)"
CMP_COUNT=$(ls reference/compact/senior-*.md 2>/dev/null | wc -l | tr -d ' ')
assert "T-B5.1 reference/compact/ has 16 profiles (got ${CMP_COUNT})" \
  "$([[ "${CMP_COUNT}" -eq 16 ]] && echo ok || echo no)"
# T-B5.2 agents/ holds only the 16 full profiles — nothing '_'-prefixed, no dirs
STRAY=$(find agents -mindepth 1 \( -type d -o -name '_*' \) 2>/dev/null | tr '\n' ' ')
assert "T-B5.2 agents/ has no subdirs or _-prefixed files" \
  "$([[ -z "${STRAY}" ]] && echo ok || echo no)" "stray:${STRAY}"

# T-B5.3 / T-B5.4 inject-profile reads relocated path + strips frontmatter
CTX=$(invoke_inject "${PLUGIN_ROOT}" "senior-distinguished-engineer")
assert "T-B5.3 inject-profile exits 0 for a full profile" \
  "$([[ "${INJECT_RC}" -eq 0 ]] && echo ok || echo no)" "rc=${INJECT_RC}"
assert "T-B5.3 injected context is non-empty" "$([[ -n "${CTX}" ]] && echo ok || echo no)"
assert "T-B5.4 injected context contains profile body heading" \
  "$(printf '%s' "${CTX}" | grep -qF '# Senior Distinguished Engineer' && echo ok || echo no)"
# frontmatter must NOT leak: no 'name:'/'description:' YAML keys in the injected text
assert "T-B5.4 injected context has no leaked 'description:' frontmatter key" \
  "$(printf '%s' "${CTX}" | grep -qE '^description:' && echo no || echo ok)"
assert "T-B5.4 injected context has no leaked 'name:' frontmatter key" \
  "$(printf '%s' "${CTX}" | grep -qE '^name:' && echo no || echo ok)"

# T-B5.5 compact-fallback bug fix (isolated copy: remove full profile, keep compact)
FB_TD=$(mktemp -d -t oj-reg-fb-XXXXXX)
# copy the subset oj-helper needs: bin/, lib/, reference/, agents/, .claude-plugin/
for d in bin lib reference agents .claude-plugin hooks; do
  [[ -e "${d}" ]] && cp -R "${d}" "${FB_TD}/"
done
FB_PROFILE="senior-test-engineer"
rm -f "${FB_TD}/agents/${FB_PROFILE}.md"   # force fallback
FB_CTX=$(invoke_inject "${FB_TD}" "${FB_PROFILE}")
assert "T-B5.5 compact fallback: exit 0 when only reference/compact/ profile exists" \
  "$([[ "${INJECT_RC}" -eq 0 ]] && echo ok || echo no)" "rc=${INJECT_RC}"
assert "T-B5.5 compact fallback: injected non-empty (compact body emitted)" \
  "$([[ -n "${FB_CTX}" ]] && echo ok || echo no)"
rm -rf "${FB_TD}"
assert "T-B5.5 regression: bin/oj-helper no longer references agents/compact" \
  "$(lacksF bin/oj-helper 'agents/compact')"

# T-B5.6 unknown profile -> exit 0, no output
UNK_CTX=$(invoke_inject "${PLUGIN_ROOT}" "nonexistent-profile-xyz")
assert "T-B5.6 unknown profile: exit 0" "$([[ "${INJECT_RC}" -eq 0 ]] && echo ok || echo no)" "rc=${INJECT_RC}"
assert "T-B5.6 unknown profile: injects nothing" "$([[ -z "${UNK_CTX}" ]] && echo ok || echo no)"

echo "-- C6: skill invocation controls --"
for s in cycle run-task sandbox-cycle delegate-sandbox save-session workstream-new; do
  assert "T-B6.1 skills/${s} sets disable-model-invocation: true" \
    "$(hasF "skills/${s}/SKILL.md" 'disable-model-invocation: true')"
done
for s in show-backlog health-check; do
  assert "T-B6.2 skills/${s} sets context: fork" "$(hasF "skills/${s}/SKILL.md" 'context: fork')"
  assert "T-B6.2 skills/${s} declares allowed-tools" "$(has "skills/${s}/SKILL.md" 'allowed-tools')"
  # read-only skills must NOT permit Write/Edit in their allowlist
  al=$(awk '/^allowed-tools:/{print; exit}' "skills/${s}/SKILL.md")
  assert "T-B6.2 skills/${s} allowed-tools excludes Write/Edit" \
    "$(printf '%s' "${al}" | grep -qE 'Write|Edit' && echo no || echo ok)" "allowed-tools: ${al}"
done

echo "-- C7: version --"
assert "T-B7.1 VERSION == 0.1.0" "$([[ "$(cat VERSION)" == "0.1.0" ]] && echo ok || echo no)"
assert "T-B7.2 plugin.json version == 0.1.0" \
  "$([[ "$(jq -r .version .claude-plugin/plugin.json)" == "0.1.0" ]] && echo ok || echo no)"
assert "T-B7.3 CHANGELOG has v0.1.0 section" "$(hasF CHANGELOG.md '## v0.1.0')"

# ══════════════════════════════════════════════════════════════════════
# Tier D — assessment recommendation traceability (14 items, P1-P5)
# ══════════════════════════════════════════════════════════════════════
echo
echo "-- Tier D: assessment recommendation traceability --"

# rec 1 DONE — covered by C1 above
pass "T-D1 (rec 1 DONE) slim injection — see T-B1.* / T-R3,R4"
# rec 2 DONE — covered by C5 above
pass "T-D2 (rec 2 DONE) registration pollution fix — see T-B5.1/5.2 / T-R1"

# rec 3 DONE — de-dup: skills reference the canonical protocol, do not restate
for s in cycle run-task; do
  assert "T-D3 (rec 3) skills/${s} references canonical execution-protocol.md" \
    "$(hasF "skills/${s}/SKILL.md" 'reference/execution-protocol.md')"
done
assert "T-D3 (rec 3) skills say 'do not duplicate it here'" \
  "$(grep -q 'do not duplicate it here' skills/cycle/SKILL.md && grep -q 'do not duplicate it here' skills/run-task/SKILL.md && echo ok || echo no)"

# rec 4 PARTIAL — description-router half landed (C4); native migration DEFERRED
assert "T-D4 (rec 4) router descriptions phrased as when-to-delegate (spot-check)" \
  "$(hasF agents/senior-software-engineer.md 'Delegate when')"
NATIVE_KEYS=$(grep -lE '^(tools|model|effort):' agents/senior-*.md 2>/dev/null | tr '\n' ' ' || true)
assert "T-D4 (rec 4) native-migration keys (tools/model/effort) genuinely absent (deferred)" \
  "$([[ -z "${NATIVE_KEYS}" ]] && echo ok || echo no)" "unexpected keyed profiles:${NATIVE_KEYS}"
assert "T-D4 (rec 4) native subagent migration documented as deferred" \
  "$(hasF CHANGELOG.md 'Native subagent migration')"

# rec 5 DEFERRED — profiles still 16-section; deferral documented
assert "T-D5 (rec 5) dead sections still present (slim NOT silently done)" \
  "$(grep -q 'Inter-Expert Collaboration' agents/senior-software-engineer.md && grep -q 'Success Indicators' agents/senior-software-engineer.md && echo ok || echo no)"
assert "T-D5 (rec 5) profile slim (16->13) documented as deferred" \
  "$(hasF CHANGELOG.md 'Profile slim from 16 to ~13 sections')"

# rec 6 DEFERRED — no clean-tree Stop hook
HOOK_EVENTS=$(jq -r '.hooks | keys | join(",")' hooks/hooks.json)
assert "T-D6 (rec 6) no Stop/PostToolUse hook added (events: ${HOOK_EVENTS})" \
  "$(printf '%s' "${HOOK_EVENTS}" | grep -qE 'Stop|PostToolUse' && echo no || echo ok)"
assert "T-D6 (rec 6) clean-tree Stop hook documented as deferred" \
  "$(hasF CHANGELOG.md 'Clean-tree Stop hook')"

# rec 7 DONE — covered by C6
pass "T-D7 (rec 7 DONE) skill invocation controls — see T-B6.1 / T-B6.2"

# rec 8 DEFERRED — no Agent Teams gate hooks
assert "T-D8 (rec 8) no TeammateIdle/TaskCompleted hook" \
  "$(printf '%s' "${HOOK_EVENTS}" | grep -qE 'TeammateIdle|TaskCompleted' && echo no || echo ok)"
assert "T-D8 (rec 8) Agent Teams quality-gate hooks documented as deferred" \
  "$(hasF CHANGELOG.md 'Agent Teams quality-gate hooks')"

# rec 9 DONE — covered by C2
pass "T-D9 (rec 9 DONE) Trivial fast-path — see T-B2.*"
# rec 10 DONE — covered by C3
pass "T-D10 (rec 10 DONE) reviewer scope — see T-B3.*"

# rec 11 DEFERRED — no cost/token line in the triage confirmation prompt
CONFIRM_LINE=$(grep -n 'triaged this as' CONDUCTOR.md 2>/dev/null | head -1 | cut -d: -f1 || true)
if [[ -n "${CONFIRM_LINE}" ]]; then
  CONFIRM_TXT=$(sed -n "${CONFIRM_LINE}p" CONDUCTOR.md)
  assert "T-D11 (rec 11) triage confirmation has no cost/token estimate (deferred)" \
    "$(printf '%s' "${CONFIRM_TXT}" | grep -qiE 'token|cost' && echo no || echo ok)"
else
  fail "T-D11 (rec 11) could not locate triage confirmation prompt"
fi
assert "T-D11 (rec 11) cost-at-triage surfacing documented as deferred" \
  "$(hasF CHANGELOG.md 'cost-at-triage surfacing')"

# rec 12 DONE — compact path fixed in the rename; senior-sre.md stale ref corrected
assert "T-D12a (rec 12) expert-index.md no longer references agents/compact/" \
  "$(lacksF reference/expert-index.md 'agents/compact')"
assert "T-D12b (rec 12) expert-index.md free of stale 'senior-sre.md'" \
  "$(lacksF reference/expert-index.md 'senior-sre.md')" \
  "expert-index.md must reference senior-site-reliability-engineer.md, not senior-sre.md"

# rec 13 PARTIAL — names gone from injected CORE (win); still prose in on-demand ref
assert "T-D13a (rec 13) CONDUCTOR core free of hard-coded model names" \
  "$(grep -qE 'sonnet|opus|fable' CONDUCTOR.md && echo no || echo ok)"
EP_MODELS=$(grep -cE 'sonnet|opus|fable' reference/execution-protocol.md || true)
skip "T-D13b (rec 13, documented remainder) model names still prose in execution-protocol.md (${EP_MODELS} refs, not sourced from platform-defaults.yaml)"

# rec 14 DONE — covered by C6
pass "T-D14 (rec 14 DONE) context: fork on read-only skills — see T-B6.2"

# ── Tier C runtime tests are not scriptable here ──────────────────────
echo
echo "-- Tier C (live-session runtime) — run manually per the test plan --"
for t in "T-R1 clean agent registry (no oj:_preamble/index/*-compact)" \
         "T-R2 profile injection at spawn (no frontmatter leak)" \
         "T-R3 slim SessionStart injection (~13.3KB)" \
         "T-R4 execution-protocol loads on demand" \
         "T-R5 Trivial fast-path at triage" \
         "T-R6 reviewer 'no material concerns' accepted" \
         "T-R7 read-only skills fork + tool-restrict"; do
  skip "${t}"
done

# ── summary ───────────────────────────────────────────────────────────
echo
echo "== summary: ${GREEN}${PASS_COUNT} pass${NC}, ${RED}${FAIL_COUNT} fail${NC}, ${YELLOW}${WARN_COUNT} warn${NC}, ${CYAN}${SKIP_COUNT} skip${NC} =="
[[ "${FAIL_COUNT}" -eq 0 ]] || exit 1
exit 0
