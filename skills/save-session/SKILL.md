---
description: Persist session state and compress carry-over before /clear; requires user approval before writing
disable-model-invocation: true
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

Throughout this document, `<session-file>` and `<backlog-file>` refer to those resolved absolute paths. This lets a project relocate state (via per-key overrides in `.claude/oj-paths.env`) without forking the skill. **Fallback:** if `oj-helper` is unavailable or prints nothing, default to `<session-file>` and `.claude/BACKLOG.md`.

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
- **Self-consistency scan (single-source drift)** — the cheap mechanical catch for duplicated facts: extract every `#<N>` / `<PREFIX>-<N>` / ticket-key token that appears **more than once** across `<backlog-file>` (and `<session-file>`), and diff the surrounding status word (`OPEN` / `MERGED` / `CLOSED` / `DONE` / etc.) across its occurrences. Any divergence — the same PR called `OPEN` in one place and `MERGED` in another — is candidate drift and MUST be flagged. This is a pure file-internal check: **no live `gh` or issue-tracker calls**, just the file's agreement with itself. It is the low-cost complement to the full re-verification a backlog audit does, and it catches exactly the duplicate-copy staleness the single-source discipline is meant to prevent.

Note any inconsistencies for inclusion in the summary.

### Step 4b — Reconcile External State (cadence-gated)

The backlog is downstream of the systems that own external state; without a periodic inbound pull, a ticket someone else closed or a PR merged outside a session sits unreflected. This step is **cadence-gated** — run it only for references stale enough to warrant re-polling (e.g. an item whose `Status` `verified <date>` stamp is older than a few days, or an item this save is about to record a decision on), so a routine save stays cheap:

- **In-flight PRs**: reuse the `gh pr view` results already gathered in Step 3 — no extra calls.
- **Issue-tracker items** (issue-tracker mode only): run `oj-helper issue-tracker-list` and compare each live status against what the referencing backlog item asserts. This uses only the `oj-helper issue-tracker-*` abstraction, so it is platform-neutral.

Report any drift (a tracker transition or PR merge/close not reflected in the backlog) as a **flagged inconsistency for the user to confirm** in the Step 7 summary. Do **not** auto-rewrite an item's scope or status from an externally-made transition — re-opening or re-scoping is a user decision. If nothing is stale enough to re-poll, state that reconciliation was a no-op.

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
