---
description: Autonomous backlog cycle (like /oj:cycle) that delegates each item's code-writing execution to a disposable sandbox container worker instead of an in-process sub-agent
---

# /oj:sandbox-cycle

Run the autonomous backlog cycle exactly as `/oj:cycle`, but **execute each item's
implementation inside a disposable `claude-sandbox` container** rather than an
in-process Task sub-agent. Triage, stakeholder analysis, adversarial review,
testing decisions, commits, backlog updates, and retrospectives all stay on the
host with you (the manager); only the code-writing step is delegated into the
sandbox via `oj-worker.sh` (the `/oj:delegate-sandbox` mechanism).

Use this when you want the cycle's *edits* contained — blast-radius control on
changes you don't want touching the host directly — while keeping host
orchestration, state, and merge authority.

> Cross-reference: `/oj:cycle` (the base protocol, inherited in full) and
> `/oj:delegate-sandbox` (the per-task dispatch this skill reuses).
> Cross-reference: `${CLAUDE_PLUGIN_ROOT}/CONDUCTOR.md` (delegation boundary, model selection).

## Why only the implementation is delegated

Task sub-agents are in-process — you cannot put one analyst in a container. The
only way to move work into the sandbox is a separate `podman run` (one worker per
dispatch). Stakeholder **analysis** and **adversarial review** don't edit
anything and need host context, so containing them adds cost (a whole container
each) for no isolation benefit. The valuable thing to contain is the step that
**writes and runs code** — so that is what this skill delegates. (If you ever
want analysis/review sandboxed too, that's a deliberate extension, not the
default.)

## Prerequisites

- The `claude-sandbox` repo, which provides `scripts/oj-worker.sh`, `scripts/sandbox-preflight.sh`,
  and builds the image on first use. Locate it via `$CLAUDE_SANDBOX_DIR`; see Pre-flight below.
- A populated `.env` in that repo (Claude + `gh`/`jira` auth) and `podman` on the host.

Run the single pre-flight command below before the first dispatch — it checks all of the above
in one shot and tells you exactly what is missing. Allowlist it once with
`Bash(*/scripts/sandbox-preflight.sh)` to suppress future permission prompts.

## Relationship to /oj:cycle

Follow `/oj:cycle`'s protocol **verbatim** — the loop, backlog resolution, the
Loop & Stop Conditions, triage (Step 3), stakeholder planning (Step 4), the
per-item commit boundary + Step 7a clean-tree gate, backlog update, and the
per-invocation retro / feedback / notify steps are all unchanged. Apply only the
overrides below.

## Overrides

### Pre-flight (once per invocation, after Step 1)

**Resolve `$CLAUDE_SANDBOX_DIR` first — once, at invocation start:**

1. Use `$CLAUDE_SANDBOX_DIR` if set.
2. If unset, use a path the user gave earlier this session.
3. If still unknown, ask the user once and `export CLAUDE_SANDBOX_DIR=<path>` for
   the remainder of this invocation — do not re-ask within the same run.

**Then run exactly this command** (verbatim — no added flags or compound operators):

```bash
"$CLAUDE_SANDBOX_DIR/scripts/sandbox-preflight.sh"
```

Parse its JSON output:

- If `.ok` is `false` (or exit code is non-zero): **stop immediately** and report
  the `.blockers` array to the user. Do NOT fall back to in-process execution —
  that would defeat the purpose of this skill.
- If `.ok` is `true`: surface any `.warnings` (e.g. first-run image build notice)
  and proceed. The image builds automatically on first dispatch.

> **Tip:** allowlist both sandbox commands once to suppress their permission
> prompts on future runs — `Bash(*/scripts/sandbox-preflight.sh)` for this
> pre-flight, and `Bash(*/scripts/oj-worker.sh*)` for the per-item worker dispatch
> in Step 5 (Execute) below.

### Triage gate (extends Step 3)

The worker has **no host credentials, no VPN, and no AWS/Terraform tooling**. If
the selected item needs any host-only capability — AWS/Britive, Terraform/
Kirkland, `github.marqeta.com` network, or other VPN-gated access — it cannot run
in the worker. **Stop the loop and surface it**, recommending plain `/oj:cycle`
for that item. Only self-contained code/test items proceed here.

### Execute (replaces Step 5, Phase 2)

Phase 1 (stakeholder analysis) and Phase 3 (adversarial review) run on the host
exactly as in `/oj:cycle`. **Phase 2 (lead implementation) is delegated to a
sandbox worker:**

1. Synthesize the Phase 1 findings into a **self-contained implementation brief**.
   The worker has none of this session's context and no oj plugin, so the brief
   must carry everything: the item spec, the synthesized stakeholder requirements,
   target files/modules, acceptance criteria, and the expected output (edit the
   working tree in place; the host will commit). No secrets in the brief — auth
   comes from the worker's `.env`.
2. Dispatch it (this is `/oj:delegate-sandbox`):
   ```bash
   CLAUDE_SANDBOX_OUTPUT_FORMAT=json \
     "$CLAUDE_SANDBOX_DIR/scripts/oj-worker.sh" "$REPO" "$BRIEF"
   ```
   `$REPO` is the working tree the cycle operates on; the worker edits it in place
   (bind mount). Read `.result` for the summary. **Non-zero exit → stop the loop
   and surface; never commit a failed worker run.**
3. Treat the worker's output as an **untrusted proposal**. Phase 3 adversarial
   review (host, model `opus` per CONDUCTOR.md) inspects the resulting
   `git -C "$REPO" diff`, not the worker's self-report.

For **Simple** tier, delegate the single implementation step to the worker the
same way (skip the multi-phase ceremony). **Complex** tier trips the `/oj:cycle`
stop condition as usual and does not run here.

### Test & Commit (Steps 6–7)

The worker may run tests in-container as part of its brief; regardless, the host
verifies tests and reviews the diff before committing. **The host commits** — the
per-item atomic commit and the Step 7a clean-tree gate stay on the host, where the
git state lives. The worker does not commit, push, or open PRs in this flow.

## Constraints

- **Sandbox-suitable items only** — self-contained code/test work; anything needing host creds/VPN/AWS/Terraform stops the loop for plain `/oj:cycle`.
- **Self-contained brief** — the worker has no session context and no oj plugin; put everything it needs in the prompt; no secrets (auth is in `.env`).
- **Worker output is untrusted** — adversarial review reads the diff; never commit a failed or unreviewed worker run.
- **Host keeps commit authority** — per-item commits + clean-tree gate run on the host; no push/merge from the loop (one-way-door stop condition unchanged).
- **Model** — the worker uses the `claude-sandbox` image's default model, outside oj's Task-tool model selection; pin via `oj-worker.sh` if needed.
- All other `/oj:cycle` constraints apply unchanged.
