---
description: Size-triggered backlog hygiene -- pin the current backlog to a git blob, then rewrite active items into the compact single-sourced schema; requires user approval before writing
disable-model-invocation: true
---

# /oj:backlog-compact

Keep the backlog small enough that a single read holds it in view, so drift stays catchable by routine edits instead of needing a dedicated audit. This skill pins the current file to a retrievable git snapshot, then rewrites active items into the compact, single-sourced schema (`${CLAUDE_PLUGIN_ROOT}/templates/backlog.md`), moving implementation narrative out to where it already lives (commits, PR descriptions, `session.md`). It never auto-writes: all changes are presented for **approval before writing**.

> Cross-reference: `${CLAUDE_PLUGIN_ROOT}/templates/backlog.md` for the target schema (workstream grouping; per-item `Status`/`Urgency`/`AC`/`Links`/`Context`; single-source discipline).
> Cross-reference: `/oj:save-session` compresses `session.md` carry-over on the same non-destructive, approval-gated pattern; this skill is its backlog analog.

## When to run

Run when EITHER trigger trips:

- The backlog exceeds roughly **500-600 lines**, or
- a single `Read` of the backlog needs more than one page to load it (a proxy for "no one edit or audit can hold the whole file in view").

Below the threshold, report the current size and stop -- compaction on a small file is churn. The user may force a run anyway.

## Protocol

### Step 0 -- Resolve the backlog path

```bash
oj-helper resolve-path backlog   # -> <backlog-file>
```

Throughout, `<backlog-file>` is that resolved absolute path. **Fallback:** if `oj-helper` prints nothing, default to `.claude/BACKLOG.md`. If the project is in issue-tracker mode (`oj-helper issue-tracker-check` returns a non-null project), there is no large local file to compact -- report that and stop.

### Step 1 -- Measure and gate

Read `<backlog-file>`. Report its line count and whether it paginated. If it is under the threshold and the user has not explicitly forced a run, say so and stop -- do not compact a small file.

### Step 2 -- Pin the current file (non-destructive snapshot, BEFORE any rewrite)

Preserve the exact current content so nothing is ever lost:

```bash
git -C <repo> hash-object -w <backlog-file>   # -> <blob-sha>; content now retrievable via `git show <blob-sha>`
```

If the backlog is tracked and the working tree is clean, the current committed blob already serves as the pin; record its commit SHA instead. Capture the pin reference -- it goes into the rewritten header's history line so the verbose prior content stays one command away.

### Step 3 -- Rewrite active items into the compact schema

Rewrite in memory (no writes yet) against `${CLAUDE_PLUGIN_ROOT}/templates/backlog.md`:

- **Preserve item ids exactly** -- never renumber. Ids are the cross-reference and graduation keys.
- **Preserve workstream structure** -- keep the Workstreams index and each workstream's goal/bottleneck/sequencing header.
- **Keep only status + blocker per open item**: `Status` (the single authoritative state, with a `verified <date>` stamp when it asserts external state), `Urgency`, `AC`, `Links`, and `Context` only when it carries reasoning a future reader genuinely needs.
- **Move narrative out**: multi-paragraph implementation logs, commit SHAs, and design rationale go to the commit history / PR description / `session.md` -- they already live there. Do not delete substance without a home; if a paragraph is load-bearing and lives nowhere else, promote it to an artifact or `session.md` first and link it.
- **Collapse closed items** to one-line markers (`~~<id>~~ -- <title> -- done <date> (<closing PR/commit>)`).
- **Update the header history line** to point at the Step 2 pin, in the pattern the template's history note uses.

### Step 4 -- Self-consistency scan (do not reintroduce drift)

Before presenting, run the same mechanical check `/oj:save-session` runs, so the rewrite does not carry a stale duplicate forward: extract every `#<N>` / `<PREFIX>-<N>` / ticket-key token that appears more than once across the rewritten backlog (and `session.md` if present), and diff the surrounding status word (`OPEN`/`MERGED`/`CLOSED`/`DONE`/etc.) across occurrences. Any mismatch is candidate drift -- resolve it in the rewrite (collapse to a single-sourced assertion) or flag it. This is a pure file-internal check: no live `gh` / issue-tracker calls required.

### Step 5 -- Present and apply

Present the rewrite as a **diff-style summary**: line count before/after, the pin reference, which items were compacted, what narrative moved out and where it landed, and any drift the Step 4 scan found. **Apply only after user approval.** On approval, write atomically -- build the full new document in memory and replace in a single write (temp file, then move over `<backlog-file>`) so no partial state is ever observable. On rejection, explain what was proposed and ask for guidance; do not silently drop the work.

## Constraints

- **Approval required** -- never auto-write; present the full diff first.
- **Non-destructive** -- pin to a retrievable git blob BEFORE rewriting; never drop content without either preserving it in the pin or relocating load-bearing substance to a linked home.
- **Preserve ids exactly** -- never renumber; ids are load-bearing cross-reference keys.
- **Single-sourced output** -- the rewrite must obey the template's single-source rule: each external-state fact asserted once (the owning item's `Status`), every other mention a pointer.
- **Atomic write** -- single-replace so a failure leaves the original untouched.
- **Graceful degradation** -- issue-tracker mode has no large local file; report and stop. If `git` is unavailable for the pin, stop and tell the user rather than rewriting without a snapshot.
