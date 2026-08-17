---
description: Adversarially review a code path or an open PR, file the findings to the reviews history area, and optionally fix the confirmed ones or post them as PR comments
argument-hint: "[--fix] [--comment] <code-path|PR-url>"
disable-model-invocation: true
---

# /oj:review

Review work that already exists - a path in the tree, or an open PR - and produce findings that survive scrutiny. This is the **ad-hoc activation mode** of `D56` (a user request with no backlog context: Triage -> Execute -> Deliver), so it does not read or select from the backlog.

`/oj:review` is an **orchestration command**: the delegation boundary in `${CLAUDE_PLUGIN_ROOT}/CONDUCTOR.md` § Delegation Boundary binds. That is load-bearing here rather than ceremonial - see Step 2.

## Step 0 - Parse the invocation

**Invocation**: `/oj:review [--fix] [--comment] <code-path|PR-url>`, optionally followed by free-form prompt text narrowing what to look for.

The full argument string is `$ARGUMENTS`. Parse and state the result before acting:

1. **Flags** - `--fix` and `--comment`, in any position, in any order. Both are optional and may be combined.
2. **`<target>`** - the first non-flag token. Either a path in the working tree (file or directory) or a PR URL / number. Required.
3. **prompt** - everything remaining: an optional focus for the review (for example "concentrate on the retry path").

Validation, before any work:

- If `<target>` is missing, print the usage line and stop.
- **`--comment` requires a PR target.** There is nowhere to post a comment for a bare path. If `--comment` is passed with a path, stop and say so - do not silently downgrade to a local-only review, because the user asked for something visible to their reviewers and would otherwise believe it happened.
- Resolve a PR target with `gh pr view <target> --json state,url,headRefName,baseRefName,mergeable`. If it is already merged or closed, say so and ask whether to continue: a review of a merged PR is still useful reading, but `--fix` and `--comment` against it usually are not what the user meant.

## Step 1 - Assemble the change under review

- **PR target**: the diff (`gh pr diff`), the base and head refs, and the PR description.
- **Path target**: the current contents plus, when the path is inside a repo with uncommitted or unmerged work, the relevant diff. State explicitly which of the two you reviewed - "the committed state of `src/api/`" and "the uncommitted diff in `src/api/`" are different reviews and the user needs to know which they got.

Report the exact scope you assembled (files, line counts, base ref) before reviewing. A review whose scope is unstated cannot be trusted later.

## Step 2 - Delegate the review to a distinct reviewer

**The manager MUST NOT perform this review itself.** Axiom 1's claim is precisely that single-agent review degenerates into coherent affirmation: an agent asked to critique material already in its own context will rationalize it. The delegation boundary is what makes the review real, so a `/oj:review` that reviews inline has removed the only mechanism it depends on.

Spawn a reviewer via the Task tool, following the Adversarial Review Protocol in `${CLAUDE_PLUGIN_ROOT}/reference/workflow-stages.md` (adversarial review protocol) - the same protocol the lifecycle's review phase uses, so findings are comparable across commands.

- Choose the reviewer role by what the change actually touches, using `${CLAUDE_PLUGIN_ROOT}/reference/expert-index.md`. Security-relevant diffs get the Security Engineer; a destructive migration gets the Data Architect; otherwise the Distinguished Engineer is the default technical reviewer.
- **Do not pass `model` or `effort` as boilerplate.** Named `oj:` roles carry their own configuration per `${CLAUDE_PLUGIN_ROOT}/CONDUCTOR.md` § Spawn Economics. In particular this skill sets no `effort` in its own frontmatter: a skill-level override changes effort mid-session, which invalidates the prompt cache and re-writes the whole prefix at cache-write price. Reviewer depth is a property of the reviewer, bound per agent.
- **Brief with files, not topics** - the concrete diff, the one question, and what is out of scope. A sub-agent inherits no conversation history.
- Scope discipline is the protocol's, unchanged: flag ONLY correctness- or requirements-affecting gaps. Style and preference are out of scope. **"No material concerns" is a valid verdict** at every tier; the FAILURE MODES TESTED section is still required.

## Step 3 - Report the findings

Report through the `ReportFindings` tool so findings render as a typed list rather than prose, ranked most severe first. Each finding carries a `verdict`:

| Verdict | Meaning | Eligible for `--fix` |
|---------|---------|----------------------|
| `CONFIRMED` | The reviewer demonstrated the defect - a concrete input or state producing the wrong result | Yes |
| `PLAUSIBLE` | Reasoned but not demonstrated | No |

An empty findings list is a real result. Report it as such.

## Step 4 - File the review artifact

A review is a point-in-time finding **about** work, so it belongs in a history area and never at the node - filing it as design would make it answer "what is the current design?" when it does not (`${CLAUDE_PLUGIN_ROOT}/reference/file-patterns.md` § A review is not a design).

Resolve the location with `oj-helper resolve-path reviews`. On exit 3 or empty output, fall back to `oj-helper resolve-path retros`, then to `oj-helper resolve-path artifacts`. **Do not hardcode a path**: a project relocates this area with a `reviews=` override in `.claude/oj-paths.env`, and a hardcoded default silently writes outside the state tree in every project that moved it.

Write one dated document: the target and exact scope reviewed, the reviewer role, the findings with verdicts, the failure modes tested, and what was fixed or posted. If the review also concluded something about what the code *should be*, **split it**: that intent goes to the node via `/oj:spec`, not into this artifact.

## Step 5 - `--fix` (only when passed)

1. **Only `CONFIRMED` findings are eligible.** Fixing a `PLAUSIBLE` finding changes working code on a guess. List anything skipped and why.
2. **A distinct agent fixes.** Not the reviewer - an agent that patches its own findings is grading its own work, which reintroduces exactly the failure Step 2 exists to prevent. Delegate to the Software Engineer role (the authoring role).
3. **Where the fix lands is decided by this rule, not improvised:**
   - The target is a PR whose head branch you can push to -> commit onto that branch.
   - Any other case, including a PR you do not own and a bare path -> a new branch and worktree off the current base, and a separate PR.
4. **Re-verify.** Run the project's checks after fixing and report the actual output. An unverified fix is a new finding, not a resolution.
5. **Pushing is a one-way door**: gate on explicit approval via `AskUserQuestion` before any push, showing the commits, the remote, and the refspec. Never push to `main`, never force-push. Pushing to a PR branch you do not own is never automatic.

## Step 6 - `--comment` (only when passed)

Posting to a PR publishes to an external platform where teammates read it.

1. **Confirm before posting.** Present the exact comment text and gate on approval. Approval is for this post only.
2. **Findings must be self-contained.** A comment MUST NOT cite the review artifact path, any `.claude/` path, or a numbered finding from a local file - those referents mean nothing to a reviewer and cannot be opened. Restate the substance inline: what is wrong, where, and what input demonstrates it. Link only things a teammate can click.
3. **Be idempotent.** Re-running must not double-post. Before posting, list existing comments (`gh pr view --json comments`) and match on a stable marker line included in every comment this skill writes (for example an HTML comment naming the reviewed head SHA). If findings for that SHA are already posted, update or skip - say which - rather than adding a duplicate set.
4. Post `CONFIRMED` findings; include `PLAUSIBLE` ones only when the user asks, and label them as unconfirmed so a reviewer can weigh them correctly.

## Constraints

- **The reviewer is always a distinct agent** - the manager never reviews inline, at any tier. This is the one constraint that cannot be relaxed for speed.
- **`--comment` requires a PR target**; it never degrades silently to a local review.
- **Nothing external is written without an explicit approval gate** - no push, no PR comment.
- **Path indirection** - the artifact location comes from `oj-helper resolve-path reviews`, never a literal path.
- **A review is not a design** - findings go to history; new intent goes to the node through `/oj:spec`.
- **Only `CONFIRMED` findings are fixed automatically.**
- **Read-only unless a flag says otherwise** - with neither `--fix` nor `--comment`, this skill changes no code and posts nothing; it reviews and files.
