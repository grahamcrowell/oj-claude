# Dev Mode

Optional developer workflow for active OpenJunto contributors. Off by default; loading this reference adds zero cost to normal users.

---

## Activation

Set the `OJ_DEVMODE` environment variable to `1`:

```bash
export OJ_DEVMODE=1
```

When set, the OpenJunto task lifecycle will route Phase 5 (Learn) output to a structured feedback file. When unset (the 99% case), dev mode is a no-op.

> **Legacy compatibility**: `JUNTO_DEVMODE=1` is accepted as a fallback for one release. New scripts should use `OJ_DEVMODE`.

---

## Feedback Path Convention

Feedback files are written under your home `${CLAUDE_PLUGIN_DATA:-$HOME/.claude/dev}/` tree, organized by repository origin and run timestamp:

```
${CLAUDE_PLUGIN_DATA:-$HOME/.claude/dev}/feedback/{org}/{repo}/{timestamp}.md
```

- `{org}` and `{repo}` are derived from the current git remote (e.g., `acme-corp/api-service`). When no remote is set, defaults to `local/{cwd-basename}`.
- `{timestamp}` is ISO-8601 in seconds (e.g., `2026-05-13T14-32-08`).

The path is computed by the helper:

```bash
oj-helper feedback-path
```

This directory is **user-created** — the OpenJunto installer does not create it. The first dev-mode session creates `${CLAUDE_PLUGIN_DATA:-$HOME/.claude/dev}/feedback/` and any required subdirectories.

---

## Scope

| Property | Value |
|----------|-------|
| Distribution | Not part of the OpenJunto release |
| Visibility | Local to your machine; never synced or shared automatically |
| Used by | Active OpenJunto contributors evaluating system behavior |
| Used for | Improving CLAUDE.md, profiles, reference files based on real session signals |

If you are not an active contributor, leave `OJ_DEVMODE` unset.

---

## Trigger

Phase 5 (Learn) of the OpenJunto task lifecycle (see `run-task` skill and `cycle` skill) calls `oj-helper feedback-path` at the end of every backlog item or cycle iteration. When `OJ_DEVMODE=1`, the helper:

1. Computes the path from git origin + timestamp.
2. Creates parent directories if needed.
3. Returns the absolute path on stdout.
4. The manager then writes a feedback file at that path using the format below.

When `OJ_DEVMODE` is unset, the helper exits 0 with no output and Phase 5 proceeds without writing anything.

---

## File Format

```markdown
---
date: 2026-05-13
item: BL-042  # or the backlog item identifier; "ad-hoc" for unscheduled work
tier: Moderate
---

## What Worked

- [Specific behavior or decision that produced good results]
- [Note which prompt, profile, or protocol drove it]

## What to Improve

- [Specific friction, ambiguity, or failure]
- [Note the cost — wasted spawn, user correction, etc.]

## OpenJunto System Suggestions

- [Proposed edit to CLAUDE.md, a profile, or a reference file]
- [Or: pattern to add to `file-patterns.md`, anti-pattern to add to `communication-standards.md`]
```

The feedback file is the raw input; promoting suggestions to `${CLAUDE_PLUGIN_ROOT}/CONDUCTOR.md` or a reference file happens manually after review.
