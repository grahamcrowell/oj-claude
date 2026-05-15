#!/usr/bin/env bash
#
# pre-commit-test.sh — fixture harness for the commit-msg hook
# (.githooks/commit-msg) and the `oj-helper install-hooks` subcommand.
#
# SCOPE: Lock in the commit-msg hook's contract — it must:
#   - block edits to snapshot-tracked files when no Regen-Source trailer
#     is present in the commit message (T1)
#   - accept the commit when a valid trailer is present (T2)
#   - reject malformed trailers (T3)
#   - pass through edits to non-tracked files unconditionally (T4)
#   - fail-open when the juntogen sibling / snapshot YAML is missing,
#     emitting a stderr WARNING and exiting 0 (T5)
#   - and that the `install-hooks` subcommand sets
#     core.hooksPath -> .githooks (T6)
#
# Despite the historical filename `pre-commit-test.sh`, the actual hook
# under test is `commit-msg` — that is the only hook git invokes with
# the commit message file path as $1, which is necessary to inspect
# the trailer. The filename is preserved for symmetry with the rest of
# the BL-025-m.5 design conversation (the "pre-commit hook" handle).
#
# Test isolation: each scenario builds a private tempdir T and creates
# a throwaway git repo + a synthetic juntogen sibling under it.
# Cleanup is a SINGLE-ARG EXIT trap (`trap 'rm -rf "$T"' EXIT`) per
# the 2026-05-08 BL-025-e.2 trap-bug lesson.
#
# Exit codes:
#   0 — all scenarios pass
#   1 — at least one scenario failed
#   2 — driver error (hook script / oj-helper missing or non-executable)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
HOOK_FILE="${PLUGIN_ROOT}/.githooks/commit-msg"
OJ_HELPER="${PLUGIN_ROOT}/bin/oj-helper"

# Live snapshot — used by T13/T14/T15 to verify that the YAML parser
# correctly anchors to the `files:` block and does NOT over-match
# sibling string-list keys (plugin_json_keys, etc.). The synthetic
# snapshot used by T1-T5 has only `files:`, so it cannot exercise
# the over-match defect. T13/T14/T15 substitute the live snapshot.
LIVE_SNAPSHOT="${PLUGIN_ROOT}/../juntogen/claude/validation/snapshots/plugin-tree.snapshot.yaml"

if [ -t 1 ]; then
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
else
    RED=''; GREEN=''; YELLOW=''; CYAN=''; NC=''
fi

[ -x "${HOOK_FILE}" ] || { echo -e "${RED}ERROR${NC} commit-msg hook not executable: ${HOOK_FILE}" >&2; exit 2; }
[ -x "${OJ_HELPER}" ] || { echo -e "${RED}ERROR${NC} oj-helper not executable: ${OJ_HELPER}" >&2; exit 2; }

PASS_COUNT=0
FAIL_COUNT=0

assert_one() {
    local label="$1"; local cond="$2"; local detail="${3:-}"
    if [ "${cond}" = "ok" ]; then
        echo -e "${GREEN}PASS${NC} ${label}"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo -e "${RED}FAIL${NC} ${label}"
        [ -n "${detail}" ] && echo -e "${CYAN}      ${detail}${NC}"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
}

# Build a synthetic two-repo layout under $T:
#   $T/oj-claude/                  (throwaway git repo)
#   $T/oj-claude/.githooks/commit-msg   (copied from PLUGIN_ROOT)
#   $T/juntogen/claude/validation/snapshots/plugin-tree.snapshot.yaml
#       (synthetic snapshot listing two tracked paths)
#
# The commit-msg hook resolves the snapshot via dirname-walk:
# `$T/oj-claude/.githooks/commit-msg` -> `$T/oj-claude` -> `$T` ->
# `$T/juntogen/...`. So the sibling layout is load-bearing.
#
# Args: $T (tempdir)
# Sets cwd to $T/oj-claude on return (each scenario commits from there).
seed_repo() {
    local T="$1"
    mkdir -p "$T/oj-claude/.githooks"
    mkdir -p "$T/juntogen/claude/validation/snapshots"

    # Synthetic snapshot YAML — minimal, with two tracked entries.
    # Format mirrors the real snapshot (2-space indent + `- "path"`).
    cat > "$T/juntogen/claude/validation/snapshots/plugin-tree.snapshot.yaml" <<'EOF'
# Synthetic snapshot for pre-commit-test.sh
snapshot_version: "1"
files:
  - "agents/index.md"
  - "CONDUCTOR.md"
EOF

    # Install the hook under test by copying (NOT symlinking — symlinks
    # interact poorly with .githooks resolution on some platforms).
    cp "${HOOK_FILE}" "$T/oj-claude/.githooks/commit-msg"
    chmod +x "$T/oj-claude/.githooks/commit-msg"

    # Initialize the git repo. Quiet to keep test output focused.
    (
        cd "$T/oj-claude"
        git init -q -b main
        git config user.email "test@example.com"
        git config user.name "Test Harness"
        git config core.hooksPath .githooks
        git config commit.gpgsign false
        # Establish a baseline commit so subsequent staged paths register
        # as modifications, not the first commit.
        echo "# initial" > .seed
        git add .seed
        # Bypass the hook for the seed commit so it doesn't ask for a
        # trailer (the seed touches no tracked file, but we still want a
        # clean baseline regardless).
        git commit -q --no-verify -m "seed"
    )
}

# Stage a file and capture the result of `git commit` with a given
# message file path. Returns the commit-msg hook's exit code via $?
# (git's exit code mirrors the hook's exit code when the hook fails).
# Sets globals: RUN_RC, RUN_STDERR
run_commit_attempt() {
    local repo_dir="$1"
    local commit_msg="$2"
    local out_file="${repo_dir}/.tmp.commit.stdout"
    local err_file="${repo_dir}/.tmp.commit.stderr"
    local rc=0
    (
        cd "${repo_dir}"
        git commit -q -m "${commit_msg}" >"${out_file}" 2>"${err_file}"
    ) || rc=$?
    RUN_RC="${rc}"
    RUN_STDERR=$(cat "${err_file}" 2>/dev/null || echo "")
    rm -f "${out_file}" "${err_file}"
}

# ────────────────────────────────────────────────────────────────────
# T1 — snapshot-tracked file staged, no trailer → BLOCK (exit 1)
# ────────────────────────────────────────────────────────────────────
scenario_t1_blocked_no_trailer() {
    local T; T=$(mktemp -d -t pre-commit-t1-XXXXXX); trap 'rm -rf "$T"' EXIT
    seed_repo "$T"

    mkdir -p "$T/oj-claude/agents"
    echo "# index v1" > "$T/oj-claude/agents/index.md"
    (cd "$T/oj-claude" && git add agents/index.md)

    run_commit_attempt "$T/oj-claude" "edit agents/index.md without trailer"

    if [ "${RUN_RC}" -ne 0 ]; then
        assert_one "T1 tracked file + no trailer: commit BLOCKED" "ok"
    else
        assert_one "T1 tracked file + no trailer: commit BLOCKED" "fail" "rc=${RUN_RC} stderr=${RUN_STDERR}"
        rm -rf "$T"; trap - EXIT; return
    fi

    if echo "${RUN_STDERR}" | grep -qF "agents/index.md"; then
        assert_one "T1 stderr lists offending file (agents/index.md)" "ok"
    else
        assert_one "T1 stderr lists offending file (agents/index.md)" "fail" "stderr=${RUN_STDERR}"
    fi

    if echo "${RUN_STDERR}" | grep -qF "Regen-Source: juntogen@"; then
        assert_one "T1 stderr surfaces required Regen-Source trailer form" "ok"
    else
        assert_one "T1 stderr surfaces required Regen-Source trailer form" "fail" "stderr=${RUN_STDERR}"
    fi

    rm -rf "$T"; trap - EXIT
}

# ────────────────────────────────────────────────────────────────────
# T2 — snapshot-tracked file + valid trailer → PASS (exit 0)
# ────────────────────────────────────────────────────────────────────
scenario_t2_pass_with_trailer() {
    local T; T=$(mktemp -d -t pre-commit-t2-XXXXXX); trap 'rm -rf "$T"' EXIT
    seed_repo "$T"

    mkdir -p "$T/oj-claude/agents"
    echo "# index v2" > "$T/oj-claude/agents/index.md"
    (cd "$T/oj-claude" && git add agents/index.md)

    # Multi-line commit message: subject + blank + trailer. git accepts
    # the literal newline via printf-substituted -m arg below; we use
    # -F to read from a file to keep the form clean.
    local msg_file="$T/oj-claude/.tmp.msg"
    cat > "${msg_file}" <<'EOF'
Update agents/index.md to reference new stakeholder

Refresh the cross-reference table.

Regen-Source: juntogen@abc123def
EOF
    local rc=0
    (
        cd "$T/oj-claude"
        git commit -q -F "${msg_file}" >/dev/null 2>"$T/oj-claude/.tmp.err"
    ) || rc=$?

    if [ "${rc}" -eq 0 ]; then
        assert_one "T2 tracked file + valid trailer: commit PASSES" "ok"
    else
        assert_one "T2 tracked file + valid trailer: commit PASSES" "fail" "rc=${rc} stderr=$(cat "$T/oj-claude/.tmp.err" 2>/dev/null)"
    fi
    rm -f "${msg_file}" "$T/oj-claude/.tmp.err"

    rm -rf "$T"; trap - EXIT
}

# ────────────────────────────────────────────────────────────────────
# T3 — snapshot-tracked file + malformed trailer → BLOCK (exit 1)
# Examples of malformed forms:
#   * non-hex sha             ("juntogen@foo")
#   * too-short sha           (<7 hex)
#   * wrong prefix            ("juntogen@", trailing-hex missing)
# Cover one representative case (non-hex). The regex behavior on
# length/charset is already locked by the hook code; this test exists
# to catch a future loosening of the pattern that would accept any
# `juntogen@<word>` form.
# ────────────────────────────────────────────────────────────────────
scenario_t3_blocked_malformed_trailer() {
    local T; T=$(mktemp -d -t pre-commit-t3-XXXXXX); trap 'rm -rf "$T"' EXIT
    seed_repo "$T"

    mkdir -p "$T/oj-claude/agents"
    echo "# index v3" > "$T/oj-claude/agents/index.md"
    (cd "$T/oj-claude" && git add agents/index.md)

    local msg_file="$T/oj-claude/.tmp.msg"
    cat > "${msg_file}" <<'EOF'
Update with malformed trailer

Regen-Source: foo
EOF
    local rc=0
    (
        cd "$T/oj-claude"
        git commit -q -F "${msg_file}" >/dev/null 2>"$T/oj-claude/.tmp.err"
    ) || rc=$?

    if [ "${rc}" -ne 0 ]; then
        assert_one "T3 tracked file + malformed trailer: commit BLOCKED" "ok"
    else
        assert_one "T3 tracked file + malformed trailer: commit BLOCKED" "fail" "rc=${rc}"
    fi
    rm -f "${msg_file}" "$T/oj-claude/.tmp.err"

    rm -rf "$T"; trap - EXIT
}

# ────────────────────────────────────────────────────────────────────
# T4 — non-snapshot-tracked file (WHY.md), no trailer → PASS
# Out-of-scope edits are unconstrained.
# ────────────────────────────────────────────────────────────────────
scenario_t4_pass_non_tracked() {
    local T; T=$(mktemp -d -t pre-commit-t4-XXXXXX); trap 'rm -rf "$T"' EXIT
    seed_repo "$T"

    # WHY.md is NOT in the synthetic snapshot's files: list — out of
    # scope, must pass through without a trailer.
    echo "# Why" > "$T/oj-claude/WHY.md"
    (cd "$T/oj-claude" && git add WHY.md)

    run_commit_attempt "$T/oj-claude" "Add WHY.md (out of scope)"

    if [ "${RUN_RC}" -eq 0 ]; then
        assert_one "T4 non-tracked file + no trailer: commit PASSES" "ok"
    else
        assert_one "T4 non-tracked file + no trailer: commit PASSES" "fail" "rc=${RUN_RC} stderr=${RUN_STDERR}"
    fi

    rm -rf "$T"; trap - EXIT
}

# ────────────────────────────────────────────────────────────────────
# T5 — FALSIFIER: missing snapshot YAML → fail-open (WARNING + exit 0)
# Even when a tracked-looking file is staged, the hook MUST NOT block
# if the snapshot YAML cannot be located. Adopter onboarding scenario
# (cloned oj-claude only, no juntogen sibling).
# ────────────────────────────────────────────────────────────────────
scenario_t5_fail_open_missing_snapshot() {
    local T; T=$(mktemp -d -t pre-commit-t5-XXXXXX); trap 'rm -rf "$T"' EXIT
    # Seed but do NOT create the juntogen sibling.
    mkdir -p "$T/oj-claude/.githooks"
    cp "${HOOK_FILE}" "$T/oj-claude/.githooks/commit-msg"
    chmod +x "$T/oj-claude/.githooks/commit-msg"

    (
        cd "$T/oj-claude"
        git init -q -b main
        git config user.email "test@example.com"
        git config user.name "Test Harness"
        git config core.hooksPath .githooks
        git config commit.gpgsign false
        echo "# seed" > .seed
        git add .seed
        git commit -q --no-verify -m "seed"
    )

    # Stage a tracked-looking path — but with no snapshot, the hook
    # has no way to know it's tracked. Must pass with WARNING.
    mkdir -p "$T/oj-claude/agents"
    echo "# index" > "$T/oj-claude/agents/index.md"
    (cd "$T/oj-claude" && git add agents/index.md)

    run_commit_attempt "$T/oj-claude" "edit without juntogen sibling"

    if [ "${RUN_RC}" -eq 0 ]; then
        assert_one "T5 missing snapshot: commit PASSES (fail-open)" "ok"
    else
        assert_one "T5 missing snapshot: commit PASSES (fail-open)" "fail" "rc=${RUN_RC} stderr=${RUN_STDERR}"
    fi

    if echo "${RUN_STDERR}" | grep -qF "WARNING: snapshot-drift check skipped"; then
        assert_one "T5 missing snapshot: stderr WARNING emitted" "ok"
    else
        assert_one "T5 missing snapshot: stderr WARNING emitted" "fail" "stderr=${RUN_STDERR}"
    fi

    rm -rf "$T"; trap - EXIT
}

# ────────────────────────────────────────────────────────────────────
# T6 — install-hooks subcommand: sets core.hooksPath to .githooks
# Verifies the opt-in installer is idempotent and reports its result.
# ────────────────────────────────────────────────────────────────────
scenario_t6_install_hooks() {
    local T; T=$(mktemp -d -t pre-commit-t6-XXXXXX); trap 'rm -rf "$T"' EXIT
    mkdir -p "$T/repo/.githooks"
    # Plant a stub executable so install-hooks sees >=1 hook.
    cat > "$T/repo/.githooks/commit-msg" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
    chmod +x "$T/repo/.githooks/commit-msg"

    (
        cd "$T/repo"
        git init -q -b main
        git config user.email "test@example.com"
        git config user.name "Test Harness"
        git config commit.gpgsign false
    )

    # First invocation: must set core.hooksPath.
    local rc=0
    local out
    out=$( (cd "$T/repo" && "${OJ_HELPER}" install-hooks 2>"$T/repo/.tmp.err") ) || rc=$?

    if [ "${rc}" -eq 0 ]; then
        assert_one "T6 install-hooks: exit 0" "ok"
    else
        assert_one "T6 install-hooks: exit 0" "fail" "rc=${rc} stderr=$(cat "$T/repo/.tmp.err" 2>/dev/null)"
        rm -rf "$T"; trap - EXIT; return
    fi

    if echo "${out}" | grep -qE "^Installed: core\.hooksPath -> \.githooks \([0-9]+ hook.* active\)$"; then
        assert_one "T6 install-hooks: stdout reports success" "ok"
    else
        assert_one "T6 install-hooks: stdout reports success" "fail" "stdout=${out}"
    fi

    local configured
    configured=$( (cd "$T/repo" && git config --get core.hooksPath 2>/dev/null) )
    if [ "${configured}" = ".githooks" ]; then
        assert_one "T6 install-hooks: git config core.hooksPath == .githooks" "ok"
    else
        assert_one "T6 install-hooks: git config core.hooksPath == .githooks" "fail" "got=${configured}"
    fi

    # Idempotency: second invocation should also succeed.
    local rc2=0
    (cd "$T/repo" && "${OJ_HELPER}" install-hooks >/dev/null 2>&1) || rc2=$?
    if [ "${rc2}" -eq 0 ]; then
        assert_one "T6 install-hooks: idempotent (second run exit 0)" "ok"
    else
        assert_one "T6 install-hooks: idempotent (second run exit 0)" "fail" "rc=${rc2}"
    fi

    rm -rf "$T"; trap - EXIT
}

# seed_repo_live — like seed_repo, but installs the LIVE
# juntogen snapshot at the sibling location instead of the synthetic
# two-entry placeholder. Used by T13/T14/T15 to exercise the YAML
# parser against the real multi-key file (files:, plugin_json_keys:,
# hooks_json_shape:, skill_frontmatter_required:, agent_counts:),
# which is necessary to reproduce the over-match defect where sibling
# string-list values like "name"/"version"/"license" would be picked
# up as if they were `files:` entries.
seed_repo_live() {
    local T="$1"
    mkdir -p "$T/oj-claude/.githooks"
    mkdir -p "$T/juntogen/claude/validation/snapshots"

    # Copy the LIVE snapshot bit-for-bit.
    cp "${LIVE_SNAPSHOT}" "$T/juntogen/claude/validation/snapshots/plugin-tree.snapshot.yaml"

    cp "${HOOK_FILE}" "$T/oj-claude/.githooks/commit-msg"
    chmod +x "$T/oj-claude/.githooks/commit-msg"

    (
        cd "$T/oj-claude"
        git init -q -b main
        git config user.email "test@example.com"
        git config user.name "Test Harness"
        git config core.hooksPath .githooks
        git config commit.gpgsign false
        echo "# initial" > .seed
        git add .seed
        git commit -q --no-verify -m "seed"
    )
}

# ────────────────────────────────────────────────────────────────────
# T13 — LIVE snapshot regression: stage a top-level file named
# `version` (a value under the sibling `plugin_json_keys:` list) →
# expect rc=0 (NOT blocked). Reproduces the Phase 3 reviewer's
# fail-CLOSED false-positive: prior grep+sed parser matched any
# indented `  - "..."` line at any indent, so values under sibling
# string-list keys (plugin_json_keys: "name", "version", "license",
# ...) were treated as tracked files. The awk fix anchors parsing
# to the `files:` block. Negative-control: top-level `version` MUST
# pass through with no trailer.
# ────────────────────────────────────────────────────────────────────
scenario_t13_over_match_version() {
    if [ ! -f "${LIVE_SNAPSHOT}" ]; then
        echo -e "${YELLOW}SKIP${NC} T13 over-match (version): live snapshot not present at ${LIVE_SNAPSHOT}"
        return
    fi
    local T; T=$(mktemp -d -t pre-commit-t13-XXXXXX); trap 'rm -rf "$T"' EXIT
    seed_repo_live "$T"

    # `version` is a value under plugin_json_keys: in the live snapshot.
    # It is NOT a path under files:. Staging a top-level file with this
    # exact name must pass through the hook untouched.
    echo "0.0.99" > "$T/oj-claude/version"
    (cd "$T/oj-claude" && git add version)

    run_commit_attempt "$T/oj-claude" "Add top-level version (NOT a tracked file)"

    if [ "${RUN_RC}" -eq 0 ]; then
        assert_one "T13 over-match: top-level 'version' file commits cleanly" "ok"
    else
        assert_one "T13 over-match: top-level 'version' file commits cleanly" "fail" "rc=${RUN_RC} stderr=${RUN_STDERR}"
    fi

    rm -rf "$T"; trap - EXIT
}

# ────────────────────────────────────────────────────────────────────
# T14 — LIVE snapshot regression: stage a top-level file named `name`
# (another value under `plugin_json_keys:`). Same defect class as T13,
# different reproducer. Belt-and-suspenders for the sibling-key
# over-match condition.
# ────────────────────────────────────────────────────────────────────
scenario_t14_over_match_name() {
    if [ ! -f "${LIVE_SNAPSHOT}" ]; then
        echo -e "${YELLOW}SKIP${NC} T14 over-match (name): live snapshot not present at ${LIVE_SNAPSHOT}"
        return
    fi
    local T; T=$(mktemp -d -t pre-commit-t14-XXXXXX); trap 'rm -rf "$T"' EXIT
    seed_repo_live "$T"

    echo "test" > "$T/oj-claude/name"
    (cd "$T/oj-claude" && git add name)

    run_commit_attempt "$T/oj-claude" "Add top-level name (NOT a tracked file)"

    if [ "${RUN_RC}" -eq 0 ]; then
        assert_one "T14 over-match: top-level 'name' file commits cleanly" "ok"
    else
        assert_one "T14 over-match: top-level 'name' file commits cleanly" "fail" "rc=${RUN_RC} stderr=${RUN_STDERR}"
    fi

    rm -rf "$T"; trap - EXIT
}

# ────────────────────────────────────────────────────────────────────
# T15 — LIVE snapshot positive control: stage an ACTUAL files: entry
# (`CONDUCTOR.md`) with no Regen-Source trailer → expect rc=1
# (BLOCKED). Confirms the awk fix preserves legitimate enforcement —
# the parser must still pick up real entries from the files: block,
# even with the more selective pattern. Regression guard against
# accidentally narrowing the matcher too far.
# ────────────────────────────────────────────────────────────────────
scenario_t15_real_files_entry_still_blocks() {
    if [ ! -f "${LIVE_SNAPSHOT}" ]; then
        echo -e "${YELLOW}SKIP${NC} T15 positive control (CONDUCTOR.md): live snapshot not present"
        return
    fi
    # Confirm CONDUCTOR.md is in the live snapshot's files: block before
    # running the test — if a future regen removes it, switch to another
    # entry. This guards against a silent test-vacuity drift.
    if ! awk '/^files:/{flag=1;next} /^[^[:space:]]/{flag=0} flag && /^[[:space:]]+-[[:space:]]+"CONDUCTOR\.md"/{found=1} END{exit !found}' "${LIVE_SNAPSHOT}"; then
        echo -e "${YELLOW}SKIP${NC} T15 positive control: CONDUCTOR.md no longer in live snapshot files: block"
        return
    fi

    local T; T=$(mktemp -d -t pre-commit-t15-XXXXXX); trap 'rm -rf "$T"' EXIT
    seed_repo_live "$T"

    echo "# Conductor" > "$T/oj-claude/CONDUCTOR.md"
    (cd "$T/oj-claude" && git add CONDUCTOR.md)

    run_commit_attempt "$T/oj-claude" "Edit CONDUCTOR.md without trailer"

    if [ "${RUN_RC}" -ne 0 ]; then
        assert_one "T15 positive control: tracked CONDUCTOR.md still BLOCKED without trailer" "ok"
    else
        assert_one "T15 positive control: tracked CONDUCTOR.md still BLOCKED without trailer" "fail" "rc=${RUN_RC} stderr=${RUN_STDERR}"
    fi

    rm -rf "$T"; trap - EXIT
}

echo -e "${YELLOW}[INFO]${NC} pre-commit-test (commit-msg hook + install-hooks)"
echo -e "${YELLOW}[INFO]${NC} hook:      ${HOOK_FILE}"
echo -e "${YELLOW}[INFO]${NC} oj-helper: ${OJ_HELPER}"
echo

scenario_t1_blocked_no_trailer
scenario_t2_pass_with_trailer
scenario_t3_blocked_malformed_trailer
scenario_t4_pass_non_tracked
scenario_t5_fail_open_missing_snapshot
scenario_t6_install_hooks
scenario_t13_over_match_version
scenario_t14_over_match_name
scenario_t15_real_files_entry_still_blocks

echo
echo "================================"
TOTAL=$((PASS_COUNT + FAIL_COUNT))
if [ "${FAIL_COUNT}" -eq 0 ]; then
    echo -e "${GREEN}PASS${NC} pre-commit-test: ${PASS_COUNT}/${TOTAL}"
    echo "================================"
    exit 0
fi
echo -e "${RED}FAIL${NC} pre-commit-test: ${FAIL_COUNT}/${TOTAL} scenario(s) failed"
echo "================================"
exit 1
