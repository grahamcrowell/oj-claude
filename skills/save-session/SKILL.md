---
description: Persist session state and compress carry-over before /clear; requires user approval before writing
---

# /save-session

Persist session state before `/clear` so context carries into the next session. All proposed changes are presented to the user for **approval before writing** — this command never auto-writes.

> Cross-reference: `${CLAUDE_PLUGIN_ROOT}/templates/session-state.md` for the session state template.
> Cross-reference: `.claude/CLAUDE.md` for project and multi-repo inventory.

## Protocol

### Step 0 — Resolve Canonical Paths

Before reading or writing any state, resolve the project's canonical paths:

```bash
oj-helper resolve-path session   # → <session-file>
oj-helper resolve-path backlog   # → <backlog-file>
```

Throughout this document, `<session-file>` and `<backlog-file>` refer to those resolved absolute paths. This lets a project relocate state (e.g. a canonical-state-root under `.claude/local/`) without forking the skill. **Fallback:** if `oj-helper` is unavailable or prints nothing, default to `<session-file>` and `.claude/BACKLOG.md`.

### Step 1 — Read Current State

Read `<session-file>` (if it exists) and `.claude/CLAUDE.md` to understand the current project context, active work, and conventions.

If `<session-file>` does **not** exist, offer to create it from the template at `${CLAUDE_PLUGIN_ROOT}/templates/session-state.md`. Do not create it silently.

### Step 2 — Scan Working State

Run `git status` in the project root to capture current branch and dirty/clean status.

For **multi-repo projects**, scan the repos listed in `.claude/CLAUDE.md` (look for a repos table or inventory). For each repo, record:

- Current branch
- Dirty or clean status
- Note repos with uncommitted changes

### Step 3 — Check In-Flight PRs

If `<session-file>` lists PRs in an "In-Flight PRs" section, check each PR's status:

- Run `gh pr view <number> --json state,statusCheckRollup,mergeable` for each PR
- Update recorded status: open, merged, closed, checks passing or failing

If no PRs are listed, **skip this step**.

### Step 4 — Verify Backlog Consistency

Read `<backlog-file>` and check:

- If the header states an item count, does it match the actual item count?
- Do any items marked "Blocked By" reference items that are now completed? (Potential unblock.)

Note any inconsistencies for inclusion in the summary.

### Step 5 — Check for Unprocessed Input

Look for ad-hoc input files in the repo root — for example `tasks.md`, `notes.md`, `TODO.md`. If found, **flag them** for user processing. Do not process or delete them.

### Step 6 — Draft Session Update

Compose an updated `<session-file>` containing:

- Current session number (increment from the previous session)
- Today's date
- Updated **In-Flight PRs** section (from Step 3)
- Updated **workspace state** (from Step 2)
- A **"Completed this session"** carry-over entry listing accomplishments
- **Compress** carry-over entries older than 2 sessions into single-line summaries
- **Remove** carry-over entries older than 14 days (git history preserves them)
- Updated **"Next Actions"** section based on current state

### Step 7 — Present and Apply

Present the complete proposed changes to the user as a **diff-style summary**:

- What will be written to `<session-file>`
- Any flagged issues: unprocessed input files, backlog inconsistencies, stale PRs

**Apply changes only after user approval.** If the user rejects the proposal, explain what was proposed and ask for guidance — do not silently drop the work.

## Constraints

- **Approval required** — never auto-write; present all changes first
- **Non-destructive** — if `<session-file>` exists, show what will change; never delete content without presenting it first
- **Graceful degradation** — if any file does not exist (no `session.md`, no `BACKLOG.md`, no PRs listed), skip that step and note the skip in the summary
- **No network calls beyond git/gh** — use only `git`, `gh`, and file reads; no external APIs
