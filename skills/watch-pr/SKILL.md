---
description: Watch an open PR through CI and code review until a human merges it - fix failing checks, address review comments, then close out the backlog item
argument-hint: "<PR-url|number> [--item ID]"
disable-model-invocation: true
---

# /oj:watch-pr

Carry an already-open PR from "opened" to "merged and closed out". This is the second half of delivery, split from `/oj:impl` on purpose: the wait for CI and for a human reviewer is open-ended, so binding it into the invocation that wrote the code would make that invocation un-resumable and would spend a session's context on waiting.

`/oj:watch-pr` is an **orchestration command** (`${CLAUDE_PLUGIN_ROOT}/CONDUCTOR.md` § Delegation Boundary): it fixes failing checks, so the delegation boundary binds and experts write the fixes.

## Resumability is the design

Every invocation **re-derives the PR's state from the PR itself** and does only what that state requires. Nothing is remembered between invocations, so a run that is interrupted, cleared, or abandoned costs nothing: invoke it again and it picks up from wherever the PR actually is. Never assume a previous invocation's conclusion still holds - check.

## Step 0 - Parse the invocation

**Invocation**: `/oj:watch-pr <PR-url|number> [--item ID]`, optionally followed by free-form prompt text.

The full argument string is `$ARGUMENTS`. Parse and state the result:

1. **`<PR-url|number>`** - required. If missing, print the usage line and stop.
2. **`[--item ID]`** - the backlog item or issue-tracker key this PR closes out. Optional; when absent, Step 4 tries to identify it from the PR and asks the user if it cannot.
3. **prompt** - any extra instruction for this run.

## Step 1 - Read the PR's current state

Run `gh pr view <target> --json state,url,isDraft,mergeable,mergeStateStatus,statusCheckRollup,reviewDecision,comments,headRefName,headRefOid` and branch on what you find. State the observed status before acting.

| Observed state | Action |
|---|---|
| Merged | Skip to Step 4 (close-out). This is the normal resumed path. |
| Closed unmerged | Report and stop. Reopening is the user's decision. |
| Checks failing | Step 2. |
| Checks green, review changes requested | Step 3. |
| Checks green, approved, still open | Step 5 - hand back for the human merge. |
| Checks still running | Step 5 - report and hand back with the wait guidance. |

## Step 2 - Fix failing checks

1. Identify the failing checks and retrieve their actual logs (`gh run view --log-failed`, or the check's own output). **Quote the real failure**; never infer a cause from a check's name.
2. Distinguish a genuine failure from an infrastructure flake. A flake is re-run once; a real failure is fixed. Say which you concluded and on what evidence - treating a real failure as a flake and re-running is how a broken change gets merged.
3. Delegate the fix to the Software Engineer role (the authoring role) with the failing log and the relevant files. Per § Spawn Economics, named roles carry their own model and effort - do not pass them as boilerplate.
4. Re-run the project's own verification locally before pushing, and report the actual output.
5. Commit and push to the PR's head branch. Pushing to the branch of an already-open PR you own is a continuation of published work rather than a new one-way door, so it does not need a fresh approval gate - but **never** force-push, and never push to `main`.
6. Return to Step 1. The push starts CI again, and re-reading the state is what makes the loop correct.

## Step 3 - Address review comments

1. Enumerate unresolved review comments and threads.
2. Triage each: a **correctness or requirements** point is addressed with a change; a **preference** point is answered, not silently obeyed; a point resting on a misreading is answered with the clarifying fact. Never resolve a thread by quietly ignoring it.
3. Delegate substantive changes as in Step 2. Re-verify, commit, push.
4. Reply on each thread with what changed, or why nothing did. **Replies are external, published text**: they must be self-contained, and must not cite a `.claude/` path, a local backlog id, or a numbered finding from a local file - restate the substance instead.
5. Return to Step 1.

## Step 4 - Close out after merge

Only once the PR reports **merged**:

1. Update the item's status to done - `oj-helper issue-tracker-transition <KEY> --status "Done"` in issue-tracker mode, or the resolved backlog file (`oj-helper resolve-path backlog`) in file-backed mode. Issue-tracker failures are non-blocking: note the key and the intended status for manual reconciliation and continue.
2. **Stamp and single-source the external state.** The `Status` line asserting the PR's state carries `verified <today>`. Then grep the backlog (and `session.md` if present) for **every other mention** of that PR number and refresh each one in the same edit - a fact about an external artifact lives in exactly one place, and every other mention references it by id.
3. Record any follow-up work the review surfaced as new backlog items rather than leaving it in the merged PR's threads.
4. Clean up the local branch and worktree only after confirming the merge, and only if the user has not asked to keep them.

## Step 5 - Hand back

When the PR is waiting on something this skill must not do - a human merge, or CI still running - stop and report: the PR URL, its check status, its review decision, and exactly what it is waiting on.

**Do not block the session waiting.** If a background or scheduled mechanism is available, offer to re-check on a sensible cadence matched to how long this project's CI actually takes. Otherwise tell the user to re-invoke `/oj:watch-pr <url>` when the state changes - which is cheap precisely because every invocation re-derives state.

## Constraints

- **Never merge.** The human merges, via the UI. This skill prepares a PR to be mergeable and closes out afterwards; it does not perform the merge, and does not enable auto-merge.
- **Never force-push, never push to `main`.**
- **Re-derive state every invocation** - no memory between runs, so resuming is always safe.
- **Idempotent** - a run against an already-merged PR does close-out once and reports it; a run against an already-fixed check does nothing and says so.
- **Delegation boundary binds** - experts write the fixes.
- **External artifact hygiene** - no local backlog ids, no `.claude/` paths in commits, PR text, or review replies. No AI attribution in commit messages.
- **A failing check is never rationalized into a pass** - if it cannot be fixed, stop and surface it.
