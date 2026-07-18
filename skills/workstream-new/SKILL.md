---
description: Scaffold a parallel-workstream directory (git worktree + linked .claude/ state) for running an isolated /oj:cycle thread against a shared workspace
disable-model-invocation: true
---

# /oj:workstream-new

Set up an isolated execution environment for a parallel `/oj:cycle` thread. Each workstream gets its own directory, its own git worktree, and a per-workstream `.claude/CLAUDE.md` enforcing a tagging discipline — while sharing the canonical `.claude/BACKLOG.md`, `.claude/state/session.md`, and `.claude/artifacts/` with every other workstream in the same workspace.

> Use this when you want to run multiple `/oj:cycle` invocations concurrently against the same workspace without file collisions. Each workstream is a separate `claude` session, each targeting its own git worktree on its own branch.

> **One workstream concept, two surfaces.** The execution workstream this skill scaffolds is the same workstream the shared backlog groups items under: the `WS-<X>` blocks (goal / sequencing / current bottleneck) defined by `${CLAUDE_PLUGIN_ROOT}/templates/backlog.md` (§ Backlog Item Schema). A parallel `/oj:cycle` thread should have a declared home in that backlog — a workstream block whose items it drains — so its work is visible and single-sourced alongside every other thread's.

## Protocol

### Step 1 — Elicit required arguments

You need at minimum:

- **WSID** — the workstream identifier (e.g. `feat-auth`, `DATA-1234`). Used as the directory name and the default branch name. Prefer a WSID that matches (or maps cleanly to) a `WS-<X>` block in the shared backlog, so the execution thread and its backlog home share one identity. If the shared backlog has no corresponding workstream block yet, flag to the user that they should add one (goal / sequencing / current bottleneck per `${CLAUDE_PLUGIN_ROOT}/templates/backlog.md`) — this skill does not edit the backlog itself.
- **REPO** — the name of the repo directory inside the workspace (e.g. `my-repo`). Must exist at `<workspace>/<repo>`.

Optional:

- **BRANCH** — the git branch to create/check out in the worktree. Defaults to `<wsid>`.
- **--workspace PATH** — explicit workspace root. Omit to let the helper walk up from `$PWD` looking for `.claude/state/session.md`.

If WSID or REPO are missing, ask for them before proceeding.

### Step 2 — Invoke the helper

Run in bash:

```bash
oj-helper workstream-new <wsid> <repo> [branch] [--workspace <path>]
```

Examples:

```bash
oj-helper workstream-new DATA-1234 my-repo
oj-helper workstream-new feat-x my-repo my-feature-branch --workspace ~/m/data-lake
```

Capture stdout and stderr. If the exit code is non-zero, surface the stderr message to the user and stop — do not attempt to continue.

### Step 3 — Surface next steps to the user

On exit 0, find the "Next steps:" block in stdout and present it verbatim to the user. It will look like:

```
Next steps:
  cd <workspace>/.workstreams/<wsid>
  claude
  > /rename <wsid>
  > /oj:cycle  <prompt targeting ./<repo>>
```

Explain that each line is for the user to run manually — in particular, the `cd` and `claude` launch must be done by the user in their terminal, not by this session.

## Constraints

- Do not execute the `cd` or launch `claude` on the user's behalf — the next-steps block is instructions for the user to carry out in a new terminal session.
- Do not modify `.claude/BACKLOG.md`, `.claude/state/session.md`, or any workspace files. The helper does all file system work.
- If the helper exits non-zero, quote its stderr verbatim and stop. Common causes: no `.claude/state/session.md` found on the walk-up (pass `--workspace`), repo directory not found in workspace, `git` not on PATH.
