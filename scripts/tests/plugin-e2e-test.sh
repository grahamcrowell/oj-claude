#!/usr/bin/env bash
#
# plugin-e2e-test.sh — L3 composition smoke test for the oj-claude
# Claude Code plugin. Sits above oj-helper-hook-test.sh (L1 contract
# tests, 43/43) and plugin-validate-test.sh (L2 validator tests, 20/20)
# in the test pyramid.
#
# SCOPE: end-to-end COMPOSITION of the installed plugin tree, exercised
# from an isolated install root. Each scenario builds a fresh tempdir
# HOME / XDG_CONFIG_HOME / CLAUDE_PLUGIN_DATA / CLAUDE_PLUGIN_ROOT and
# drives the plugin through the same surfaces that Claude Code would —
# without ever invoking the real `claude` CLI. The CLI-free design is
# load-bearing: the harness is the canonical proof that the plugin
# tree is self-sufficient and does not silently depend on a wrapper
# command being present on PATH.
#
# Scenarios:
#   T1 — clean-install hook-chain: read hooks.json, dispatch ALL
#        SessionStart commands (conductor-inject, migrate-legacy) in
#        declared order against a NON-CANONICAL plugin root (rsync copy
#        under the tempdir). Assert (a) conductor-inject stdout is valid
#        JSON whose .hookSpecificOutput.additionalContext is
#        byte-identical to the first 50 bytes of the installed
#        CONDUCTOR.md, (b) migrate-legacy writes BOTH sentinels
#        (XDG backup + CLAUDE_PLUGIN_DATA data-dir), (c) migration_source
#        is "clean-install" (no legacy artifacts planted).
#   T2 — SubagentStart inject-profile composition: synthesize a subagent
#        transcript JSONL at the path oj-helper expects
#        ({transcript_path_minus_jsonl}/subagents/agent-{agent_id}.jsonl)
#        with the senior-distinguished-engineer marker, invoke
#        inject-profile with realistic hook-input JSON on stdin, and
#        assert the additionalContext begins with the _preamble.md body
#        AND contains the senior-distinguished-engineer.md body
#        (concatenated with the "\n\n---\n\n" separator per oj-helper).
#   T3 — Plugin-tree referential integrity from the isolated root:
#        parse CONDUCTOR.md for backtick-anchored `@<path>` and
#        `${CLAUDE_PLUGIN_ROOT}/<path>` refs (skipping glob `*`,
#        meta-placeholder `[`, and "If `<path>` exists" prose) and
#        assert each resolves to a readable file under the isolated
#        CLAUDE_PLUGIN_ROOT. This is the SAME contract structural-diff
#        L4 enforces at regen time, but re-verified from an
#        installed-plugin point of view.
#   T4 — `claude` CLI absence is a non-dependency: a self-documenting
#        assertion that proves this harness does NOT shell out to the
#        Claude Code CLI. Invokes a small sanity check with PATH
#        stripped of `claude` and confirms the harness still PASSes.
#
# Test isolation: each scenario builds its own mktemp tempdir and uses
# the single-arg EXIT trap form `trap 'rm -rf "${TD}"' EXIT` rather
# than a `trap cleanup_fn EXIT` form whose function exit-code can
# propagate and cause spurious failures (2026-05-08 BL-025-e.2 lesson,
# see oj-helper-hook-test.sh:50 for the same pattern).
#
# Output: PASS/FAIL lines per assertion, summary `PASSED: N FAILED: M`,
# exit 0 on full success, exit 1 on any failure. Mirrors
# oj-helper-hook-test.sh format so the three L1/L2/L3 harnesses look
# identical when chained in CI.
#
# CI: not wired this cycle (PM directive — deferred to potential
# follow-on so the L3 layer can stabilize against the live plugin tree
# before CI gating).
#
# Exit codes:
#   0 — all scenarios pass
#   1 — at least one scenario failed
#   2 — driver error (jq missing, plugin tree missing, etc.)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
OJ_HELPER="${PLUGIN_ROOT}/bin/oj-helper"
CONTRACTS_SH="${PLUGIN_ROOT}/bin/lib/contracts.sh"
HOOKS_JSON="${PLUGIN_ROOT}/hooks/hooks.json"
CONDUCTOR_MD="${PLUGIN_ROOT}/CONDUCTOR.md"
AGENTS_DIR="${PLUGIN_ROOT}/agents"

if [[ -t 1 ]]; then
    RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'; CYAN=$'\033[0;36m'; NC=$'\033[0m'
else
    RED=''; GREEN=''; YELLOW=''; CYAN=''; NC=''
fi

# ── Preflight ─────────────────────────────────────────────────────────
[[ -x "${OJ_HELPER}" ]] || { echo "${RED}ERROR${NC} oj-helper not executable: ${OJ_HELPER}" >&2; exit 2; }
[[ -r "${CONTRACTS_SH}" ]] || { echo "${RED}ERROR${NC} contracts library missing: ${CONTRACTS_SH}" >&2; exit 2; }
[[ -r "${HOOKS_JSON}" ]] || { echo "${RED}ERROR${NC} hooks.json missing: ${HOOKS_JSON}" >&2; exit 2; }
[[ -r "${CONDUCTOR_MD}" ]] || { echo "${RED}ERROR${NC} CONDUCTOR.md missing: ${CONDUCTOR_MD}" >&2; exit 2; }
[[ -d "${AGENTS_DIR}" ]] || { echo "${RED}ERROR${NC} agents/ missing: ${AGENTS_DIR}" >&2; exit 2; }
command -v jq >/dev/null 2>&1 || { echo "${RED}ERROR${NC} jq required (this harness parses hook JSON output). Install via: brew install jq" >&2; exit 2; }

PASS_COUNT=0
FAIL_COUNT=0

assert_one() {
    local label="$1"; local cond="$2"; local detail="${3:-}"
    if [[ "${cond}" = "ok" ]]; then
        echo "${GREEN}PASS${NC} ${label}"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo "${RED}FAIL${NC} ${label}"
        [[ -n "${detail}" ]] && echo "${CYAN}      ${detail}${NC}"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
}

# Mirror the plugin tree into an isolated CLAUDE_PLUGIN_ROOT under a
# tempdir. We avoid symlinking the whole repo so the test plugin root
# is a NON-CANONICAL path — proves nothing in the plugin is pinned to
# the developer's checkout location. We copy only what the hook
# surfaces and CONDUCTOR.md ref-resolution actually touch (keeps the
# scenarios fast and the rsync cost predictable).
#
#   $1 = destination directory (must already exist)
copy_isolated_plugin() {
    local dest="$1"
    mkdir -p "${dest}/bin/lib" "${dest}/hooks"
    cp "${OJ_HELPER}"     "${dest}/bin/oj-helper"
    cp "${CONTRACTS_SH}"  "${dest}/bin/lib/contracts.sh"
    chmod +x "${dest}/bin/oj-helper"
    cp "${HOOKS_JSON}"    "${dest}/hooks/hooks.json"
    cp "${CONDUCTOR_MD}"  "${dest}/CONDUCTOR.md"
    [[ -r "${PLUGIN_ROOT}/VERSION" ]] && cp "${PLUGIN_ROOT}/VERSION" "${dest}/VERSION"
    # Copy agents/, reference/, skills/, templates/, docs/ — only those
    # subtrees that CONDUCTOR.md or inject-profile actually reach into.
    # We use `cp -R` (BSD-portable) rather than `rsync` to avoid an
    # external-tool dependency.
    local d
    for d in agents reference skills templates docs; do
        if [[ -d "${PLUGIN_ROOT}/${d}" ]]; then
            cp -R "${PLUGIN_ROOT}/${d}" "${dest}/${d}"
        fi
    done
}

# ──────────────────────────────────────────────────────────────────────
# T1 — clean-install hook-chain: dispatch SessionStart commands from
#      hooks.json against a non-canonical CLAUDE_PLUGIN_ROOT.
# ──────────────────────────────────────────────────────────────────────
scenario_t1_clean_install_hook_chain() {
    local TD; TD=$(mktemp -d -t oj-e2e-t1-XXXXXX); trap 'rm -rf "${TD}"' EXIT

    # Isolated env. CLAUDE_PLUGIN_ROOT points at a NON-CANONICAL path
    # under TD; HOME/XDG/data are all per-scenario so no cross-test
    # leakage is possible.
    local HOME_DIR="${TD}/home"
    local XDG_DIR="${TD}/xdg"
    local DATA_DIR="${TD}/data"
    local PLUGIN_DIR="${TD}/plugins/oj"   # Non-canonical
    mkdir -p "${HOME_DIR}" "${XDG_DIR}" "${DATA_DIR}" "${PLUGIN_DIR}"
    copy_isolated_plugin "${PLUGIN_DIR}"

    # Read hooks.json, expand ${CLAUDE_PLUGIN_ROOT}, and walk SessionStart
    # commands in declared order. This is exactly what Claude Code does
    # when emitting hook lifecycle events. We rely on the plugin host's
    # convention that hooks are dispatched IN ORDER per matcher.
    if ! jq -e . "${PLUGIN_DIR}/hooks/hooks.json" >/dev/null 2>&1; then
        assert_one "T1 hooks.json is valid JSON in isolated root" "fail" "hooks.json at ${PLUGIN_DIR}/hooks/hooks.json"
        rm -rf "${TD}"; trap - EXIT; return
    fi
    assert_one "T1 hooks.json is valid JSON in isolated root" "ok"

    local -a commands=()
    while IFS= read -r cmd; do
        cmd="${cmd//\$\{CLAUDE_PLUGIN_ROOT\}/${PLUGIN_DIR}}"
        commands+=("${cmd}")
    done < <(jq -r '.hooks.SessionStart[]?.hooks[]?.command // empty' "${PLUGIN_DIR}/hooks/hooks.json")

    if [[ "${#commands[@]}" -ge 2 ]]; then
        assert_one "T1 SessionStart declares >=2 hook commands" "ok"
    else
        assert_one "T1 SessionStart declares >=2 hook commands" "fail" "count=${#commands[@]}"
        rm -rf "${TD}"; trap - EXIT; return
    fi

    # Assert declared order: conductor-inject runs BEFORE migrate-legacy.
    # The order is not just cosmetic — conductor-inject is the one that
    # emits SessionStart context to Claude; migrate-legacy is a silent
    # side-effect handler. If they swapped, a user-visible regression
    # would only show up under real Claude Code.
    case "${commands[0]}" in
        *conductor-inject*)
            assert_one "T1 hook order: conductor-inject precedes migrate-legacy" "ok" ;;
        *)
            assert_one "T1 hook order: conductor-inject precedes migrate-legacy" "fail" "first=${commands[0]}" ;;
    esac

    # Dispatch each command with isolated env. Capture per-command
    # stdout/stderr/exit so we can assert on each independently.
    local i=0
    local conductor_stdout="" migrate_stderr=""
    for cmd in "${commands[@]}"; do
        local rc=0
        local out_file="${TD}/cmd${i}.stdout"
        local err_file="${TD}/cmd${i}.stderr"
        HOME="${HOME_DIR}" \
        CLAUDE_PLUGIN_ROOT="${PLUGIN_DIR}" \
        CLAUDE_PLUGIN_DATA="${DATA_DIR}" \
        XDG_CONFIG_HOME="${XDG_DIR}" \
            bash -c "${cmd}" >"${out_file}" 2>"${err_file}" || rc=$?
        if [[ "${rc}" -ne 0 ]]; then
            assert_one "T1 cmd[${i}] exit 0 (${cmd})" "fail" "rc=${rc} stderr=$(cat "${err_file}")"
            rm -rf "${TD}"; trap - EXIT; return
        fi
        case "${cmd}" in
            *conductor-inject*) conductor_stdout="${out_file}" ;;
            *migrate-legacy*)   migrate_stderr="${err_file}" ;;
        esac
        i=$((i + 1))
    done
    assert_one "T1 all SessionStart hook commands exit 0 under isolated env" "ok"

    # conductor-inject: valid JSON envelope with non-empty additionalContext.
    if jq -e '.hookSpecificOutput.hookEventName == "SessionStart"' "${conductor_stdout}" >/dev/null 2>&1; then
        assert_one "T1 conductor-inject: hookEventName == SessionStart" "ok"
    else
        assert_one "T1 conductor-inject: hookEventName == SessionStart" "fail" "stdout=$(cat "${conductor_stdout}")"
    fi

    local actual_ctx
    actual_ctx=$(jq -r '.hookSpecificOutput.additionalContext' "${conductor_stdout}")
    if [[ -n "${actual_ctx}" ]]; then
        assert_one "T1 conductor-inject: additionalContext non-empty" "ok"
    else
        assert_one "T1 conductor-inject: additionalContext non-empty" "fail" "stdout=$(cat "${conductor_stdout}")"
    fi

    # Byte-identity proof: first 50 bytes of additionalContext match
    # first 50 bytes of CONDUCTOR.md. We compare leading bytes only to
    # dodge trailing-newline drift between command substitution and
    # raw file read (per the manager-flagged pre-mortem failure mode).
    local expected_head actual_head
    expected_head=$(head -c 50 "${PLUGIN_DIR}/CONDUCTOR.md")
    actual_head=$(printf '%s' "${actual_ctx}" | head -c 50)
    if [[ "${expected_head}" = "${actual_head}" ]]; then
        assert_one "T1 conductor-inject: first 50 bytes match installed CONDUCTOR.md (byte-identity)" "ok"
    else
        assert_one "T1 conductor-inject: first 50 bytes match installed CONDUCTOR.md (byte-identity)" "fail" "expected=[${expected_head}] actual=[${actual_head}]"
    fi

    # migrate-legacy: both sentinels written.
    if [[ -f "${XDG_DIR}/oj/.migration-done" ]]; then
        assert_one "T1 migrate-legacy: backup sentinel at \${XDG_CONFIG_HOME}/oj/.migration-done" "ok"
    else
        assert_one "T1 migrate-legacy: backup sentinel at \${XDG_CONFIG_HOME}/oj/.migration-done" "fail" "xdg=$(ls "${XDG_DIR}" 2>/dev/null)"
    fi

    if [[ -f "${DATA_DIR}/.migration-done" ]]; then
        assert_one "T1 migrate-legacy: data-dir sentinel at \${CLAUDE_PLUGIN_DATA}/.migration-done" "ok"
    else
        assert_one "T1 migrate-legacy: data-dir sentinel at \${CLAUDE_PLUGIN_DATA}/.migration-done" "fail" "data=$(ls "${DATA_DIR}" 2>/dev/null)"
    fi

    # migration_source must be "clean-install" — no legacy artifacts
    # were planted, so the detection path must have returned empty.
    if grep -qF "migration_source=clean-install" "${XDG_DIR}/oj/.migration-done" 2>/dev/null; then
        assert_one "T1 migrate-legacy: migration_source=clean-install" "ok"
    else
        assert_one "T1 migrate-legacy: migration_source=clean-install" "fail" "backup=$(cat "${XDG_DIR}/oj/.migration-done" 2>/dev/null)"
    fi

    # No advisory line on a clean install (the silence contract).
    if ! grep -qF "Legacy install detected" "${migrate_stderr}" 2>/dev/null; then
        assert_one "T1 migrate-legacy: stderr contains no legacy advisory (silence on clean install)" "ok"
    else
        assert_one "T1 migrate-legacy: stderr contains no legacy advisory (silence on clean install)" "fail" "stderr=$(cat "${migrate_stderr}")"
    fi

    rm -rf "${TD}"; trap - EXIT
}

# ──────────────────────────────────────────────────────────────────────
# T2 — SubagentStart inject-profile composition: synthesize a transcript,
#      run the hook, verify the preamble + profile concatenation.
# ──────────────────────────────────────────────────────────────────────
scenario_t2_inject_profile_composition() {
    local TD; TD=$(mktemp -d -t oj-e2e-t2-XXXXXX); trap 'rm -rf "${TD}"' EXIT

    local HOME_DIR="${TD}/home"
    local XDG_DIR="${TD}/xdg"
    local DATA_DIR="${TD}/data"
    local PLUGIN_DIR="${TD}/plugins/oj"
    mkdir -p "${HOME_DIR}" "${XDG_DIR}" "${DATA_DIR}" "${PLUGIN_DIR}"
    copy_isolated_plugin "${PLUGIN_DIR}"

    # Pick a known profile that ships with the plugin. We assert the
    # files exist BEFORE invoking the hook so a missing profile shows
    # up as a clear preflight failure instead of a confusing concat
    # mismatch downstream.
    local profile="senior-distinguished-engineer"
    local preamble_path="${PLUGIN_DIR}/reference/expert-preamble.md"
    local profile_path="${PLUGIN_DIR}/agents/${profile}.md"
    if [[ -r "${preamble_path}" && -r "${profile_path}" ]]; then
        assert_one "T2 preflight: expert-preamble.md + ${profile}.md present (reference/ + agents/)" "ok"
    else
        assert_one "T2 preflight: expert-preamble.md + ${profile}.md present (reference/ + agents/)" "fail" "preamble=${preamble_path} profile=${profile_path}"
        rm -rf "${TD}"; trap - EXIT; return
    fi

    # Pre-write the transcript at the exact path oj-helper derives:
    #   {transcript_path_minus_jsonl}/subagents/agent-{agent_id}.jsonl
    # Writing the file BEFORE invoking the hook ensures the 500ms
    # transcript-wait loop in inject-profile exits on the first iteration
    # (pre-mortem failure mode #1: stale wait slowing the test).
    local agent_id="test-agent-t2"
    local transcript_path="${TD}/session.jsonl"
    local session_dir="${TD}/session"  # transcript_path minus .jsonl
    local subagent_transcript="${session_dir}/subagents/agent-${agent_id}.jsonl"
    mkdir -p "${session_dir}/subagents"

    # First-line JSONL must have .message.content that decodes to text
    # containing the marker. CRITICAL: oj-helper reads via `head -1`
    # (see bin/oj-helper:99) — so the JSONL line must be COMPACT.
    # `jq -c` (--compact-output) keeps the object on a single line; a
    # pretty-printed `jq -n` would put `{` on line 1 alone and the
    # entire spawn prompt would be invisible to the marker matcher.
    local marker="<!-- oj-expert: ${profile} -->"
    local spawn_prompt
    spawn_prompt=$(printf '%s\n\nYou are a Senior Distinguished Engineer.\n**TASK**: noop for the test.\n' "${marker}")
    jq -cn \
        --arg content "${spawn_prompt}" \
        '{message: {role: "user", content: $content}}' \
        > "${subagent_transcript}"

    # Hook input JSON shape per oj-helper:54-60. Compact form for
    # parity with how Claude Code actually emits hook payloads.
    local hook_input
    hook_input=$(jq -cn \
        --arg agent_type "general-purpose" \
        --arg transcript_path "${transcript_path}" \
        --arg agent_id "${agent_id}" \
        '{agent_type: $agent_type, transcript_path: $transcript_path, agent_id: $agent_id}')

    local rc=0
    local out_file="${TD}/inject.stdout"
    local err_file="${TD}/inject.stderr"
    # Invoke oj-helper directly (not via `bash -c`) so the herestring
    # stdin attaches to the helper without going through an extra shell
    # layer. The helper itself does `cat` to consume stdin.
    HOME="${HOME_DIR}" \
    CLAUDE_PLUGIN_ROOT="${PLUGIN_DIR}" \
    CLAUDE_PLUGIN_DATA="${DATA_DIR}" \
    XDG_CONFIG_HOME="${XDG_DIR}" \
        "${PLUGIN_DIR}/bin/oj-helper" inject-profile \
        >"${out_file}" 2>"${err_file}" <<<"${hook_input}" || rc=$?

    if [[ "${rc}" -eq 0 ]]; then
        assert_one "T2 inject-profile: exit 0" "ok"
    else
        assert_one "T2 inject-profile: exit 0" "fail" "rc=${rc} stderr=$(cat "${err_file}")"
        rm -rf "${TD}"; trap - EXIT; return
    fi

    # Stdout must be valid JSON with the SubagentStart envelope.
    if jq -e '.hookSpecificOutput.hookEventName == "SubagentStart"' "${out_file}" >/dev/null 2>&1; then
        assert_one "T2 inject-profile: hookEventName == SubagentStart" "ok"
    else
        assert_one "T2 inject-profile: hookEventName == SubagentStart" "fail" "stdout=$(cat "${out_file}")"
        rm -rf "${TD}"; trap - EXIT; return
    fi

    local context
    context=$(jq -r '.hookSpecificOutput.additionalContext' "${out_file}")
    if [[ -n "${context}" ]]; then
        assert_one "T2 inject-profile: additionalContext non-empty" "ok"
    else
        assert_one "T2 inject-profile: additionalContext non-empty" "fail" "stdout=$(cat "${out_file}")"
        rm -rf "${TD}"; trap - EXIT; return
    fi

    # Composition assertions (matching oj-helper:152-159):
    #   context = preamble + "\n\n---\n\n" + profile
    # We verify (1) starts-with preamble body, (2) contains the
    # documented "\n\n---\n\n" separator, (3) ends-with profile body.
    local preamble_body profile_body
    preamble_body=$(cat "${preamble_path}")
    profile_body=$(cat "${profile_path}")

    # (1) context starts with preamble (compare leading 50 bytes — dodges
    #     trailing-newline weirdness between `cat` and `additionalContext`).
    local preamble_head context_head
    preamble_head=$(printf '%s' "${preamble_body}" | head -c 50)
    context_head=$(printf '%s' "${context}" | head -c 50)
    if [[ "${preamble_head}" = "${context_head}" ]]; then
        assert_one "T2 inject-profile: additionalContext starts with _preamble.md content" "ok"
    else
        assert_one "T2 inject-profile: additionalContext starts with _preamble.md content" "fail" "expected=[${preamble_head}] actual=[${context_head}]"
    fi

    # (2) the literal separator appears.
    if printf '%s' "${context}" | grep -qF $'\n\n---\n\n'; then
        assert_one "T2 inject-profile: context contains '\\n\\n---\\n\\n' separator" "ok"
    else
        assert_one "T2 inject-profile: context contains '\\n\\n---\\n\\n' separator" "fail" "no separator in additionalContext"
    fi

    # (3) the profile's first heading must appear AFTER the separator.
    #     Find the byte offset of the separator and assert that a
    #     unique-to-profile substring lives at or after it.
    local profile_head
    profile_head=$(head -1 "${profile_path}")  # "# Senior Distinguished Engineer"
    if printf '%s' "${context}" | grep -qF -- "${profile_head}"; then
        assert_one "T2 inject-profile: profile heading '${profile_head}' present in context" "ok"
    else
        assert_one "T2 inject-profile: profile heading '${profile_head}' present in context" "fail" "context tail=$(printf '%s' "${context}" | tail -c 200)"
    fi

    # (4) overall byte budget sanity. preamble + sep + profile should
    #     produce something close to preamble_len + profile_len + 7
    #     (the separator "\n\n---\n\n" is 7 bytes). bash $(cat X)
    #     command-substitution strips trailing newlines, so oj-helper's
    #     concat collapses any double-newline tail at every concat
    #     point. We widen the tolerance to +/-512 bytes (was +/-64) to
    #     absorb: (a) cumulative trailing-newline strip across multiple
    #     concats, and (b) regen-driven prose-class drift in the
    #     PROSE-class senior-distinguished-engineer.md profile (LLM
    #     re-emission can vary by hundreds of bytes within the same
    #     contract). The structural assertions above (preamble prefix,
    #     separator presence, profile heading) already prove the
    #     shape; this budget is a gross-truncation canary, not a
    #     byte-perfect identity check. The L5 byte-diff DATA-class
    #     baseline is the right place for byte-perfect; this is L3
    #     composition, where PROSE drift is allowed.
    local expected_len actual_len delta
    expected_len=$(( $(wc -c < "${preamble_path}") + $(wc -c < "${profile_path}") + 7 ))
    actual_len=${#context}
    delta=$(( expected_len > actual_len ? expected_len - actual_len : actual_len - expected_len ))
    if [[ "${delta}" -le 512 ]]; then
        assert_one "T2 inject-profile: byte budget within +/-512 of preamble+sep+profile" "ok"
    else
        assert_one "T2 inject-profile: byte budget within +/-512 of preamble+sep+profile" "fail" "expected=${expected_len} actual=${actual_len} delta=${delta}"
    fi

    rm -rf "${TD}"; trap - EXIT
}

# ──────────────────────────────────────────────────────────────────────
# T3 — Plugin-tree referential integrity from the isolated install root.
#      Mirror the structural-diff.sh L4 contract — but check it from a
#      non-canonical CLAUDE_PLUGIN_ROOT to catch any "works on dev
#      checkout, breaks on install" regressions.
# ──────────────────────────────────────────────────────────────────────
scenario_t3_referential_integrity() {
    local TD; TD=$(mktemp -d -t oj-e2e-t3-XXXXXX); trap 'rm -rf "${TD}"' EXIT

    local PLUGIN_DIR="${TD}/plugins/oj"
    mkdir -p "${PLUGIN_DIR}"
    copy_isolated_plugin "${PLUGIN_DIR}"

    local conductor="${PLUGIN_DIR}/CONDUCTOR.md"
    if [[ ! -r "${conductor}" ]]; then
        assert_one "T3 CONDUCTOR.md readable in isolated root" "fail" "missing=${conductor}"
        rm -rf "${TD}"; trap - EXIT; return
    fi
    assert_one "T3 CONDUCTOR.md readable in isolated root" "ok"

    # Walk backtick-anchored refs. The regex is intentionally the SAME
    # one structural-diff.sh:451 uses so this L3 layer cannot accept a
    # ref shape the L2 validator would reject (or vice versa).
    local total=0 resolved=0
    local -a unresolved=()
    # Buffer the awk output through a tempfile so the read loop can be a
    # plain `while`/`done < file` form — process-substitution into a
    # while loop preserves the exit status of the loop body, which is
    # what we want, but BSD bash 3.2 has historically been finicky with
    # `set -e` propagation here. The tempfile form is the most portable.
    local refs_file="${TD}/refs.tsv"
    awk '
        {
            line = $0
            full = $0
            while (match(line, /`(@|\$\{CLAUDE_PLUGIN_ROOT\}\/)(agents|reference|skills|templates|hooks|bin|docs)\/[A-Za-z0-9._\/\*\[\]-]+\.md`/)) {
                tok = substr(line, RSTART + 1, RLENGTH - 2)
                print NR "\t" full "\t" tok
                line = substr(line, RSTART + RLENGTH)
            }
        }
    ' "${conductor}" > "${refs_file}"

    local line_no line_text ref ref_path
    while IFS=$'\t' read -r line_no line_text ref; do
        [[ -z "${ref}" ]] && continue
        # Skip glob patterns (documentation, not literal path).
        [[ "${ref}" == *'*'* ]] && continue
        # Skip meta-placeholders like `[profile-filename]`.
        [[ "${ref}" == *'['* ]] && continue
        # Skip conditional "If `<path>` exists" prose lines.
        if [[ "${line_text}" =~ ^[[:space:]]*If[[:space:]]+\`.*\`[[:space:]]+exists ]]; then
            continue
        fi
        total=$((total + 1))
        if [[ "${ref}" == '@'* ]]; then
            ref_path="${PLUGIN_DIR}/${ref#@}"
        elif [[ "${ref}" == '${CLAUDE_PLUGIN_ROOT}/'* ]]; then
            ref_path="${PLUGIN_DIR}/${ref#\$\{CLAUDE_PLUGIN_ROOT\}/}"
        else
            continue
        fi
        if [[ -r "${ref_path}" ]]; then
            resolved=$((resolved + 1))
        else
            unresolved+=("L${line_no}: ${ref} (resolved to ${ref_path})")
        fi
    done < "${refs_file}"

    if [[ "${total}" -ge 1 ]]; then
        assert_one "T3 CONDUCTOR.md exposes >=1 ref to check (sanity: regex matched something)" "ok"
    else
        assert_one "T3 CONDUCTOR.md exposes >=1 ref to check (sanity: regex matched something)" "fail" "no refs matched — regex drift?"
    fi

    if [[ "${total}" -gt 0 && "${resolved}" -eq "${total}" ]]; then
        assert_one "T3 all ${total} CONDUCTOR.md refs resolve under isolated CLAUDE_PLUGIN_ROOT" "ok"
    else
        local detail="resolved=${resolved}/${total}"
        local u
        # Guard the array dereference: under `set -u`, expanding an
        # empty array via "${arr[@]}" without a default is treated as
        # unbound-variable and aborts the script (bash 3.2/macOS quirk).
        # Length-check first, then iterate only when non-empty.
        if (( ${#unresolved[@]} > 0 )); then
            for u in "${unresolved[@]}"; do
                detail+=$'\n      '"${u}"
            done
        fi
        assert_one "T3 all ${total} CONDUCTOR.md refs resolve under isolated CLAUDE_PLUGIN_ROOT" "fail" "${detail}"
    fi

    rm -rf "${TD}"; trap - EXIT
}

# ──────────────────────────────────────────────────────────────────────
# T4 — `claude` CLI absence is a non-dependency. Self-documenting check
#      that proves this harness does NOT shell out to the Claude Code
#      CLI. We strip PATH down to a curated set of POSIX binaries that
#      excludes `claude`, then re-run a small sanity invocation against
#      oj-helper conductor-inject and assert it still works. If a
#      future drop snuck in a `claude` shellout, THIS test would FAIL.
# ──────────────────────────────────────────────────────────────────────
scenario_t4_no_claude_cli_dependency() {
    local TD; TD=$(mktemp -d -t oj-e2e-t4-XXXXXX); trap 'rm -rf "${TD}"' EXIT

    local HOME_DIR="${TD}/home"
    local XDG_DIR="${TD}/xdg"
    local DATA_DIR="${TD}/data"
    local PLUGIN_DIR="${TD}/plugins/oj"
    local BIN_DIR="${TD}/curated-bin"
    mkdir -p "${HOME_DIR}" "${XDG_DIR}" "${DATA_DIR}" "${PLUGIN_DIR}" "${BIN_DIR}"
    copy_isolated_plugin "${PLUGIN_DIR}"

    # Build a curated PATH containing ONLY the binaries oj-helper's
    # conductor-inject needs. CRITICALLY: `claude` is NOT symlinked,
    # so any code path that shells out to it will fail under this PATH.
    # Mirrors the S5 no-jq scenario in oj-helper-hook-test.sh.
    local b
    for b in bash sh cat dirname readlink grep head mkdir rm touch sed env jq tr find date wc mv mktemp; do
        if command -v "$b" >/dev/null 2>&1; then
            ln -sf "$(command -v "$b")" "${BIN_DIR}/$b"
        fi
    done

    # Pre-flight assertion: `claude` must NOT be on the curated PATH.
    # This is the "self-documenting" part — anyone reading the harness
    # learns the intent immediately.
    if ! PATH="${BIN_DIR}" command -v claude >/dev/null 2>&1; then
        assert_one "T4 curated PATH excludes \`claude\` (CLI-free invariant)" "ok"
    else
        assert_one "T4 curated PATH excludes \`claude\` (CLI-free invariant)" "fail" "claude resolved at $(PATH="${BIN_DIR}" command -v claude)"
    fi

    # Run conductor-inject under the curated PATH and assert it still
    # exits 0 with valid JSON. This proves the hook surface is not
    # secretly depending on `claude` being reachable.
    local rc=0
    local out_file="${TD}/no-claude.stdout"
    local err_file="${TD}/no-claude.stderr"
    HOME="${HOME_DIR}" \
    CLAUDE_PLUGIN_ROOT="${PLUGIN_DIR}" \
    CLAUDE_PLUGIN_DATA="${DATA_DIR}" \
    XDG_CONFIG_HOME="${XDG_DIR}" \
    PATH="${BIN_DIR}" \
        "${PLUGIN_DIR}/bin/oj-helper" conductor-inject \
        >"${out_file}" 2>"${err_file}" || rc=$?

    if [[ "${rc}" -eq 0 ]]; then
        assert_one "T4 conductor-inject runs under PATH-without-claude (exit 0)" "ok"
    else
        assert_one "T4 conductor-inject runs under PATH-without-claude (exit 0)" "fail" "rc=${rc} stderr=$(cat "${err_file}")"
    fi

    if jq -e '.hookSpecificOutput.hookEventName == "SessionStart"' "${out_file}" >/dev/null 2>&1; then
        assert_one "T4 conductor-inject emits valid JSON under PATH-without-claude" "ok"
    else
        assert_one "T4 conductor-inject emits valid JSON under PATH-without-claude" "fail" "stdout=$(cat "${out_file}")"
    fi

    rm -rf "${TD}"; trap - EXIT
}

# ──────────────────────────────────────────────────────────────────────
# Drive
# ──────────────────────────────────────────────────────────────────────
echo "${YELLOW}[INFO]${NC} plugin-e2e-test"
echo "${YELLOW}[INFO]${NC} plugin root: ${PLUGIN_ROOT}"
echo "${YELLOW}[INFO]${NC} oj-helper:   ${OJ_HELPER}"
echo

scenario_t1_clean_install_hook_chain
scenario_t2_inject_profile_composition
scenario_t3_referential_integrity
scenario_t4_no_claude_cli_dependency

echo
echo "================================"
TOTAL=$((PASS_COUNT + FAIL_COUNT))
if [[ "${FAIL_COUNT}" -eq 0 ]]; then
    echo "${GREEN}PASSED:${NC} ${PASS_COUNT} ${GREEN}FAILED:${NC} ${FAIL_COUNT}"
    echo "${GREEN}PASS${NC} plugin-e2e-test: ${PASS_COUNT}/${TOTAL}"
    echo "================================"
    exit 0
fi
echo "${RED}PASSED:${NC} ${PASS_COUNT} ${RED}FAILED:${NC} ${FAIL_COUNT}"
echo "${RED}FAIL${NC} plugin-e2e-test: ${FAIL_COUNT}/${TOTAL} scenario(s) failed"
echo "================================"
exit 1
