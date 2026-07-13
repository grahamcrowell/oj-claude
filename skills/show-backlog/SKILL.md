---
description: Display a read-only summary of the current backlog grouped by priority
allowed-tools: [Bash, Read, Grep, Glob]
context: fork
---

# /show-backlog

Display a concise, read-only summary of the current backlog. This command does not modify the backlog, transition tickets, or start work — it is a visibility surface only.

> Cross-reference: `/run-task` for the full task lifecycle that consumes the backlog.
> Cross-reference: `.claude/CLAUDE.md` for project-specific backlog conventions.

## Protocol

### Step 1 — Backlog Source Detection

Run `oj-helper issue-tracker-check` in bash. Parse the result:

```
exit code != 0                         -> BACKLOG.md mode
exit code == 0, project == null        -> BACKLOG.md mode
exit code == 0, project == "KEY"       -> issue tracker mode with KEY
```

Decision tree:
- `issue-tracker-check` fails (non-zero exit) → **BACKLOG.md mode**
- `issue-tracker-check` succeeds and `"project"` is null → **BACKLOG.md mode**
- `issue-tracker-check` succeeds and `"project"` is non-null → **issue tracker mode** with that project key

> This logic is identical to `/run-task`. Keep the two in sync.

### Step 2 — Load Backlog Items

- **issue tracker mode**: Run `oj-helper issue-tracker-list --project PROJECT_KEY`. Parse the JSON response to extract `key`, `summary`, `status`, and `priority` for each item.
- **BACKLOG.md mode**: Resolve the backlog path with `oj-helper resolve-path backlog` (fallback `.claude/BACKLOG.md` if it prints nothing), then read it. Parse the markdown structure to extract `ID`, `title`, and `status` per item, grouped by priority section (P0-P4).

### Step 3 — Present Summary

#### Header

- State the backlog source — the project key (issue tracker mode) or `BACKLOG.md` (BACKLOG.md mode)
- State the total count of **open** items

#### Items by Priority/Status

Group items by priority. For each item, show:

- **ID** — issue tracker key (e.g., `PROJ-123`) or the local backlog ID **exactly as written** in the file. Do not assume a `BACK-` prefix: match whatever `<PREFIX>-<N>` scheme the backlog uses (e.g. `BACK-12`, `L-071`).
- **Title / Summary**
- **Status** — Open, In Progress, Blocked, etc.

Omit empty priority groups. Omit a Completed section — this view shows open items only.

#### Next Cycle Candidate

Highlight the single highest-priority **unblocked** item as the recommended candidate for the next `/run-task` invocation. If multiple items share the highest priority, pick the **oldest by creation date**.

## Constraints

- **Read-only information display** — no backlog modifications, no ticket transitions, no work started
- **Concise output** — titles are sufficient; do not repeat full descriptions
- **Empty backlog handling** — if there are no open items, say so clearly and suggest the user add items before running `/run-task`
