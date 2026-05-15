# Session State

> Updated: {YYYY-MM-DD}, session {N}

<!-- This is the volatile layer at `.claude/state/session.md`. Updated at session boundaries via the session save command. Contrast with `.claude/CLAUDE.md`, which is stable across sessions. Old content ages out via the carry-over retention policy below. -->

---

## In-Flight PRs

<!-- PRs opened but not yet merged or closed. Checked at session start via `gh pr view`. -->

| # | Repo | Title | Status | Notes |
|---|------|-------|--------|-------|
| 1 | {org/repo} | {PR title} | {Open / Draft / Approved / Changes Requested} | {Reviewer, blocker, next action} |
| 2 | {org/repo} | {PR title} | {Status} | {Notes} |

---

## Local Workspace State

<!-- Per-repo snapshot of working-tree state. Dirty column shows "clean" or a short list of modified files; Unpushed is a commit count. -->

| Repo | Branch | Dirty | Unpushed | Notes |
|------|--------|-------|----------|-------|
| {org/repo} | {branch} | clean / {FILES} | {COUNT} | {Context — e.g., "WIP on auth middleware"} |
| {org/repo} | {branch} | clean / {FILES} | {COUNT} | {Notes} |

---

## Session Carry-Over

<!--
Retention policy:
  - Most recent 3 sessions: full detail
  - >7 days old: compress to single-line summary (what happened, outcome)
  - >14 days old: remove from this file; if still load-bearing, promote to CLAUDE.md or an ADR

Compression happens at session save time.
-->

*Completed this session ({YYYY-MM-DD}, session {N}):*

1. {Accomplishment — what shipped, what decided, what unblocked}
2. {Accomplishment}
3. {Accomplishment}

*Completed session {N-1} ({YYYY-MM-DD}):*

1. {Accomplishment}
2. {Accomplishment}

*Completed session {N-2} ({YYYY-MM-DD}):*

1. {Accomplishment}

*Older (compressed):*

- {YYYY-MM-DD}: {One-line summary — event and outcome}
- {YYYY-MM-DD}: {One-line summary}

---

## Next Actions

<!-- Concrete starting points for the next session. Written so future-you can act without re-reading the full carry-over. -->

1. {Next action — specific enough to act on immediately}
2. {Next action}
3. {Next action}
