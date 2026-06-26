# step-01-workstream-new

Generation prompt for the `workstream-new` subcommand surface.

Regenerates three artifacts from the OpenJunto spec:

1. `bin/oj-helper` — the `cmd_workstream_new` function and its helpers
2. `scripts/tests/oj-helper-hook-test.sh` — scenario S15 (dispatcher routing, help discoverability, workspace resolution, scaffold + idempotency)
3. `skills/workstream-new/SKILL.md` — the `/oj:workstream-new` slash command

---

## Spec Inputs

### Primary spec source

**Axiom 8 — graceful degradation** (`CONDUCTOR.md`, lines 172–179):

> **Fallback (Axiom 8 — graceful degradation)**: When `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` is unset (or the host environment otherwise disables the agent-teams feature), `TeamCreate`, `TeamDelete`, `shutdown_request`, and `SendMessage` are unavailable. In that case, Complex tier degrades to a **deputy-coordinator parallel-Task-tool fan-out** … Run `oj-helper agent-teams-check` and parse `.available` from the JSON stdout. The probe always exits 0 — read `.available`, not the exit code.

Axiom 8 establishes the general principle that drives this workstream feature: when full multi-agent coordination is unavailable, fall back to a parallel-process substrate that still preserves every quality gate. The `workstream-new` subcommand is the file-system counterpart — it provides isolated working directories so multiple `/oj:cycle` invocations can run against the same workspace without colliding on files, while sharing canonical state.

Also relevant from `CONDUCTOR.md` (lines 162–170, the Complex tier file-conflict note):

> **File Conflict Avoidance**: use git worktrees for overlapping file edits (isolated working directories, shared git history).

### Workstream concept (introduced in this feature)

A **workstream** is an isolated execution environment for a single `/oj:cycle` thread:

- Lives at `<workspace>/.workstreams/<wsid>/`
- Contains a git worktree of `<repo>` at `./<repo>` (branch: `<branch>`, default: `<wsid>`)
- Has a `.claude/` directory whose `state/session.md`, `BACKLOG.md`, and `artifacts/` are SYMLINKS to the canonical workspace `.claude/` — all workstreams read and write the same shared files
- Has a `.claude/CLAUDE.md` that is a real file (never a symlink) carrying the tagging discipline

### Per-workstream tagging discipline

Every entry appended to shared state files MUST be tagged `[ws: <wsid>]` so entries remain attributable. Entries owned by other workstreams MUST NOT be edited. The workstream tag MUST NOT appear in externally visible artifacts (PR titles, commit messages, issue tracker entries) — the branch name and issue key are the correct external identifiers.

---

## Task Definition

### Helper subcommand (`bin/oj-helper`)

Implement `cmd_workstream_new` and its three private helpers:

**`_workstream_resolve_workspace <explicit>`**
Echoes the resolved workspace path or empty string. Workspace = any directory containing `.claude/state/session.md`. Resolution order:
1. `--workspace <path>` (if provided, must exist)
2. `$PWD` if `$PWD/.claude/state/session.md` exists
3. Walk up from `$PWD` to the first ancestor with `.claude/state/session.md`
4. Empty string on failure

**`_workstream_link_one <workspace> <dst-claude-dir> <relative-path> <required|optional>`**
Replaces `<dst>/<rel>` with a symlink to `<workspace>/.claude/<rel>`. If the target is already a correct symlink, print `ok`. If it is a real file, back it up with a timestamp suffix before replacing. If the source does not exist: fail loudly when `required`, skip silently when `optional`.

**`_workstream_link_all <workspace> <dst-claude-dir>`**
Links three paths: `state/session.md` (required), `BACKLOG.md` (required), `artifacts` (optional).

**`cmd_workstream_new [--workspace <path>] <wsid> <repo> [branch]`**
1. Parse positional args and `--workspace` flag. `wsid` and `repo` are required.
2. Default `branch` to `wsid` when omitted.
3. Resolve workspace via `_workstream_resolve_workspace`; die with `could not resolve workspace` if empty.
4. Verify `$workspace/$repo` exists and contains `.git`; die with actionable message if not.
5. `mkdir -p "$ws_dir/.claude"` where `ws_dir="$workspace/.workstreams/$wsid"`.
6. Print a header block (Workspace, Workstream, Repo, Branch).
7. Call `_workstream_link_all` to symlink shared state into `$ws_dir/.claude/`.
8. Write `$ws_dir/.claude/CLAUDE.md` (real file) if and only if it does not already exist. Content: the tagging rule, the don't-touch-other-workstreams rule, and the no-workstream-tag-in-external-artifacts rule (see Per-workstream CLAUDE.md section below).
9. Create the git worktree at `$ws_dir/$repo` on `$branch`. If the branch already exists in the source repo, `git worktree add <path> <branch>`; otherwise `git worktree add <path> -b <branch>`. If the worktree path already has `.git`, print `ok` and skip.
10. Call `_workstream_link_all` to symlink shared state into `$ws_dir/$repo/.claude/` (worktree also gets the shared state).
11. Print a "Next steps" block:
    ```
    cd <ws_dir>
    claude
    > /rename <wsid>
    > /oj:cycle  <prompt targeting ./<repo>>
    ```

**Dispatcher routing** — add to the `case` block:
```
workstream-new)  shift; cmd_workstream_new "$@" ;;
```

**Help text** — include `workstream-new` in the SUBCOMMANDS list with one-line description `Scaffold a parallel-workstream dir (git worktree + linked .claude/ state)`.

**Exit codes**:
- `0` — workstream created or already present; summary on stdout
- `1` — driver error (workspace not resolved, repo missing, etc.) via `die`
- `2` — usage error via `die`

### Per-workstream CLAUDE.md

The file written to `$ws_dir/.claude/CLAUDE.md` must contain all three rules:

1. **Tagging rule** — every new entry to `BACKLOG.md`, `state/session.md`, or `artifacts/` must carry `[ws: <wsid>]`.
2. **Don't-touch-other-workstreams rule** — entries tagged with a different workstream (or untagged entries not authored in this session) must not be edited or removed.
3. **No workstream tag in external artifacts** — the branch name and issue-tracker key are the correct identifiers for PR titles, commit messages, and external surfaces; never include `[ws: <wsid>]` in externally visible artifacts.

The file must also note that `.claude/state/`, `.claude/BACKLOG.md`, and `.claude/artifacts/` are symlinks to the canonical workspace, and name `./<repo>` as a git worktree on `<branch>`.

### Test scenarios (`scripts/tests/oj-helper-hook-test.sh`)

Implement `scenario_s15_workstream_new` after `scenario_s14_agent_teams_check` and before the driver echo. Add a call to it in the driver block. Extend the file-header comment block with an S15 entry.

**S15a — help discoverability**
Assert `oj-helper help` stdout contains the literal substring `workstream-new`. Falsifier for help text drift.

**S15b — dispatcher routing**
Run `oj-helper workstream-new` (no args) in a clean tempdir. Assert: exit non-zero AND stderr contains `WSID is required`. This proves the token routed to `cmd_workstream_new` and hit its usage check — not the `Unknown subcommand` branch.

**S15c — workspace resolution failure**
Run from a tempdir with no `.claude/state/session.md` anywhere on the walk-up. Pass valid wsid and repo. Assert: exit non-zero AND stderr contains `could not resolve workspace`.

**S15d — positive scaffold + idempotency**
Build a minimal fake workspace: `mkdir -p .claude/state && touch .claude/state/session.md && touch .claude/BACKLOG.md && mkdir -p myrepo && (cd myrepo && git init -q && git config user.email a@b && git config user.name a && git commit -q --allow-empty -m init)`. Run `oj-helper workstream-new feat1 myrepo --workspace <tempdir>`. Assert:
- exit 0
- `.workstreams/feat1/.claude/state/session.md` is a symlink
- `.workstreams/feat1/.claude/CLAUDE.md` is a real file (not a symlink) containing `[ws: feat1]`
- `.workstreams/feat1/myrepo/.git` exists

Re-run the same command. Assert:
- exit 0
- `.workstreams/feat1/.claude/CLAUDE.md` content is unchanged (idempotency — file was not overwritten)

Guard the entire S15d sub-scenario with `command -v git` — if git is not available, emit a SKIP assertion via `assert_one`.

Use the same `mktemp -d` + `trap 'rm -rf "$T"' EXIT` discipline as S14. Each sub-scenario gets its own `T` with the trap set and cleared (`trap - EXIT`) before the next sub-scenario allocates its own.

### Slash command (`skills/workstream-new/SKILL.md`)

Implement `/oj:workstream-new` following the `show-backlog/SKILL.md` structure:
- YAML frontmatter with `description:` (one sentence)
- Body: when to use, protocol (argument elicitation + bash invocation + surface "Next steps" to user), constraints

---

## Verification Checklist

The generated output must satisfy all of the following before it is considered correct.

### Subcommand — idempotency
- Re-running `workstream-new` against an already-scaffolded workstream exits 0.
- Existing real files in `$ws_dir/.claude/` are backed up with a timestamp before being replaced with symlinks (not silently overwritten or lost).
- `.claude/CLAUDE.md` is never overwritten on a second run — the `if [[ ! -e "$claude_md" ]]` guard is present.

### Subcommand — help discoverability
- `oj-helper help` (or `oj-helper --help`) output includes the literal string `workstream-new`.

### Subcommand — dispatcher routing
- The dispatcher `case` block routes `workstream-new)` to `cmd_workstream_new`.
- Running `oj-helper workstream-new` with no args exits non-zero with stderr containing `WSID is required` — NOT `Unknown subcommand`.

### Subcommand — usage errors
- Missing WSID: stderr contains `WSID is required` and the usage hint.
- Missing REPO: stderr contains `REPO is required` and the usage hint.
- `--workspace` points to a non-existent path: stderr contains `--workspace path does not exist`.
- Walk-up finds no session.md: stderr contains `could not resolve workspace`.
- All usage errors exit non-zero.

### Per-workstream CLAUDE.md content
- Contains `[ws: <wsid>]` tagging rule.
- Contains the don't-touch-other-workstreams rule.
- Contains the no-workstream-tag-in-external-artifacts rule.

### Test scenario S15
- S15a asserts help text contains `workstream-new`.
- S15b asserts exit non-zero + stderr contains `WSID is required` (not `Unknown subcommand`).
- S15c asserts exit non-zero + stderr contains `could not resolve workspace`.
- S15d asserts exit 0, symlink at `state/session.md`, real file at `.claude/CLAUDE.md` containing `[ws: feat1]`, worktree `.git` present; second run exits 0 with CLAUDE.md content unchanged.
- S15d is SKIP-guarded when `git` is not on PATH.
- Each sub-scenario uses an isolated tempdir with trap cleanup.

### Slash command
- `skills/workstream-new/SKILL.md` exists with YAML frontmatter containing `description:`.
- Body names the slash command `/oj:workstream-new`.
- Body instructs the LLM to invoke `oj-helper workstream-new <wsid> <repo> [branch] [--workspace <path>]` in bash.
- Body says to surface the "Next steps" tail to the user.
- Body says NOT to execute the `cd` or launch `claude` — print the next-steps for the user.
