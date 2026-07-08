---
description: Delegate one self-contained implementation task to an isolated, disposable sandbox container (plain Claude Code), then review the result on the host
---

# /oj:delegate-sandbox

Hand one self-contained implementation task to a **disposable sandbox worker** —
a plain Claude Code container (the `claude-sandbox` image, no oj plugin inside) —
instead of, or in addition to, a Task-tool sub-agent. The worker runs with
permission prompts disabled but is contained: one mounted repo, its own network,
and a built-in guardrail that lets it open a PR but **never** approve, merge,
label (`pr-bot-please`), or force-push. Orchestration, state, and merge authority
stay on the host with you (the manager).

Use this for the **Execute** step of a task whose implementation you want
isolated from the host — untrusted changes, blast-radius control, or a parallel
workstream. It preserves the delegation boundary: the sandbox worker is the
implementer; the manager coordinates and reviews.

> Cross-reference: `${CLAUDE_PLUGIN_ROOT}/CONDUCTOR.md` (delegation boundary, model selection).
> Pairs with `/oj:workstream-new` — give each parallel workstream its own git worktree and run that worktree's implementation in a separate sandbox worker.

## Prerequisites

- The **`claude-sandbox`** repo, which provides `scripts/oj-worker.sh` and builds
  the image on first use. Resolve its location from `$CLAUDE_SANDBOX_DIR`; if
  unset, ask the user for the path (e.g. `~/m/gcrowell/claude-sandbox`).
- A populated `.env` in that repo (Claude + `gh`/`jira` auth) — the worker loads it.
- `podman` on the host.

Verify all of the above in one shot: `"$CLAUDE_SANDBOX_DIR/scripts/sandbox-preflight.sh"`. Allowlist both sandbox commands once to suppress their permission prompts: `Bash(*/scripts/sandbox-preflight.sh)` (this check) and `Bash(*/scripts/oj-worker.sh*)` (the Step 2 dispatch).

## Protocol

### Step 1 — Gather inputs

- **TASK** — a precise, **self-contained** instruction. The worker has none of
  this session's context, so the prompt must carry everything: what to change, in
  which files/modules, acceptance criteria, and the expected output (open a PR, or
  just leave a working-tree diff).
- **REPO** — absolute path to the target repo or git worktree to mount. For a
  parallel thread, use the worktree from `/oj:workstream-new`.
- **SANDBOX_DIR** — `$CLAUDE_SANDBOX_DIR`, else ask the user.

If TASK or REPO is missing, ask before proceeding — do not fabricate the task.

### Step 2 — Dispatch to the worker

Run in bash, capturing stdout and the exit code:

```bash
CLAUDE_SANDBOX_OUTPUT_FORMAT=json \
  "$SANDBOX_DIR/scripts/oj-worker.sh" "$REPO" "$TASK"
```

- The worker edits `$REPO` in place (bind mount) and prints its final response as
  JSON — read `.result` for the summary.
- For long prompts, pipe the TASK on stdin instead of passing it as an argument.
- **Non-zero exit** → surface the worker's stderr to the user and stop; do not
  report success.

### Step 3 — Review on the host (mandatory)

Do not rubber-stamp the worker — treat its output as an untrusted proposal.
Inspect what changed:

```bash
git -C "$REPO" status
git -C "$REPO" diff
```

For **Moderate/Complex** tasks, spawn an adversarial reviewer via the Task tool
(model `fable` per CONDUCTOR.md § Model Selection): find the single most important
problem and test documented failure modes.

### Step 4 — Land it

- If the worker opened a PR, review it; **merge is a human action** — both the
  worker's guardrail and your branch protection forbid the worker merging.
- If the worker only edited the working tree, commit per oj conventions (atomic
  commits, no AI attribution), or delegate the commit.
- Update the backlog / issue tracker via `oj-helper` exactly as `/oj:run-task` does.

## Constraints

- **Worker output is untrusted** — always review the diff before landing; never auto-merge.
- **One task per dispatch** — keep the delegated unit bounded and reviewable.
- **Self-contained TASK** — the worker has none of this session's context; put everything it needs in the prompt.
- **No secrets in the TASK string** — auth comes from the worker's `.env`, not the prompt.
- **Merge stays on the host** — the worker can open a PR but never approve, merge, label, or force-push.
- **Model** — the worker uses the `claude-sandbox` image's default model, outside oj's Task-tool model selection; pin it by extending `oj-worker.sh` if needed.
- **Delegation boundary preserved** — the sandbox worker implements; the manager coordinates, reviews, and lands.
