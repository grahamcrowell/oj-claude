---
description: Deliver one backlog item as a reviewed draft PR - select the item, isolate a branch and worktree, run the task lifecycle, then push and open a draft PR
argument-hint: "<project/domain> [backlog-id|issue-key] [--branch NAME]"
disable-model-invocation: true
---

# /oj:impl

Take ONE unblocked backlog item from selected to **draft PR opened**, with the adversarial review already done. This skill is a **composition**, not a second lifecycle: item selection, triage, execution, and testing are the 5-phase task lifecycle in `${CLAUDE_PLUGIN_ROOT}/skills/run-task/SKILL.md`, and this skill adds only what that lifecycle does not do - branch isolation up front, and PR delivery at the end. Do not restate the lifecycle here; run it.

`/oj:impl` is an **orchestration command**: the delegation boundary in `${CLAUDE_PLUGIN_ROOT}/CONDUCTOR.md` § Delegation Boundary binds for the whole invocation. The manager selects, isolates, gates, and reports; experts write the code.

## Step 0 - Parse the invocation

**Invocation**: `/oj:impl <project/domain> [backlog-id|issue-key] [--branch NAME]`, optionally followed by free-form prompt text.

The full argument string is `$ARGUMENTS`. Parse and state the result before acting:

1. **`<project/domain>`** - the subject, a `/`-separated node path. Required; it scopes item selection and is passed to `oj-helper resolve-path ... --node <project/domain>` for any document this run files.
2. **`[backlog-id|issue-key]`** - the item to implement, if the next token matches an id shape (`<PREFIX>-<N>` or an issue-tracker key). Optional; when absent, Step 1 selects one.
3. **`[--branch NAME]`** - work on this branch instead of creating one. Optional.
4. **prompt** - everything remaining: extra context for this run.

If `<project/domain>` is missing, print the usage line and stop.

## Step 1 - Select the item

**With an id**: load that item and skip to Step 2.

**Without an id**: do not pick silently.

1. Detect the backlog source and load items exactly as the task lifecycle's Phase 1 does (`oj-helper issue-tracker-check`, else `oj-helper resolve-path backlog`) - same detection, so the three skills agree on what the backlog is.
2. Filter to **unblocked implementation work** for this subject: items whose `Blocked By` predecessors are all done and whose acceptance criteria call for writing code. An item that wants a decision, a document, or a spec is not implementation work - route it to `/oj:spec` and say so rather than implementing around it.
3. Summarize the top unblocked candidates by priority (id, title, why it is ready, its verification command) and **recommend one**, preferring implementation items.
4. Put the choice to the user via `AskUserQuestion`, with your recommendation first. If nothing is unblocked, report that and stop - do not invent work.

## Step 2 - Isolate the work

Never implement on `main`, and never on a dirty tree.

1. Confirm the working tree is clean. If it is not, stop and surface it: a dirty tree means someone else's work is in flight, and committing it into this item's PR is how unrelated changes get merged unnoticed.
2. Fetch the latest default branch (`git fetch origin`) and base the work on it. State the base commit.
3. Create the branch and an isolated working copy, unless `--branch` named an existing one:
   - If the project uses workstreams, reuse `oj-helper workstream-new <wsid> <repo> [branch]` so the run gets the standard worktree plus linked shared state.
   - Otherwise create a plain worktree on a new branch off the fetched base.
4. **Branch naming obeys External Artifact Hygiene** (`${CLAUDE_PLUGIN_ROOT}/CONDUCTOR.md`): a local backlog id MUST NOT appear in the branch name. Issue-tracker keys are the exception and SHOULD appear. Derive the name from the work, not the bookkeeping.

## Step 3 - Run the task lifecycle

Run the 5-phase lifecycle from `${CLAUDE_PLUGIN_ROOT}/skills/run-task/SKILL.md` against the selected item, in the isolated working copy, through **Phase 4 Deliver up to and including the local commit**. That covers triage and tier confirmation, live-state reconciliation, stakeholder engagement, execution, the adversarial review, and running the item's verification command. Its rules apply unchanged - in particular:

- The item's **verification command runs verbatim** and its actual output is the evidence. A non-zero exit is a hard block: stop, surface the command and output, do not push.
- The **adversarial review is mandatory** at Moderate and above and its reviewer is a distinct agent. `/oj:impl` does not add a second review and does not skip this one.
- Spawns follow `${CLAUDE_PLUGIN_ROOT}/CONDUCTOR.md` § Spawn Economics: named `oj:` roles carry their own model, effort and turn cap; any ad-hoc spawn passes an explicit `model`.

Stop here and hand back to the user if the review returns blocking findings. A draft PR is not the place to park work that failed its own review.

## Step 4 - One-way-door gate (mandatory, before any push)

`git push` is an irreversible, externally visible action. `D56` names it a one-way door and the cycle-runner stop conditions require it to be surfaced rather than performed autonomously. So this skill does not push on its own authority.

Present, in one block, and gate on explicit approval via `AskUserQuestion`:

- the branch name and base commit;
- the commits to be pushed, one line each;
- the verification command run and its actual result;
- the adversarial review verdict;
- the exact remote and refspec, and the fact that a **draft** PR will be opened.

**Write nothing to the remote until approved.** On rejection, stop; the work stays local on its branch and nothing is published. Approval covers this push and this PR only - it does not carry to a later invocation.

## Step 5 - Push and open the draft PR

1. Push the branch to the fork remote. Never push to `main`, never force-push.
2. Open the PR **as a draft**, targeting the default branch. Title and body describe the change; per External Artifact Hygiene the body carries no local backlog id and no path under `.claude/` - restate the substance instead, or link a published artifact a reviewer can actually open. Include the verification command and its result.
3. Record the PR reference on the backlog item as its single source of external state, stamped `verified <today>`, and set the item in progress (issue-tracker mode: `oj-helper issue-tracker-transition`). Do not mark it done - it is not merged.
4. **Stop.** Report the PR URL and tell the user that `/oj:watch-pr <url>` carries it through CI, review, and merge close-out.

## Constraints

- **One item per invocation** - `/oj:impl` does not loop. The multi-item form is `/oj:cycle`.
- **Ends at the draft PR** - this skill never merges, never marks the item done, and never waits on a human. Watching and closing out is `/oj:watch-pr`, which is separately invocable and resumable, so an interrupted session loses nothing.
- **Delegation boundary binds** - the manager coordinates; experts implement.
- **No push without the Step 4 gate** - and no push to `main`, no force-push, no merge.
- **External artifact hygiene** - no local backlog ids or `.claude/` paths in branch names, commit messages, or PR text. No AI attribution in commit messages.
- **Stop and ask** if blocked or uncertain, rather than guessing.
