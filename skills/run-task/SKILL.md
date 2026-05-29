---
description: Execute a single backlog item end-to-end through the 5-phase task lifecycle
---

# /run-task

Execute one backlog item end-to-end through the OpenJunto 5-phase task lifecycle: Discover, Triage, Execute, Deliver, Learn. The manager coordinates expert agents per the delegation boundary; this command does not relax that constraint.

> Cross-reference: `.claude/CLAUDE.md` for triage criteria, execution models, and quality gates.
> Cross-reference: `${CLAUDE_PLUGIN_ROOT}/reference/workflow-stages.md` and `${CLAUDE_PLUGIN_ROOT}/reference/stakeholder-guide.md` for stage-specific protocols.

## Protocol

### Phase 1 — Initialize (Discover)

#### Backlog Source Detection

Run `oj-helper issue-tracker-check` in bash. Parse the result:

```
exit code != 0                         -> BACKLOG.md mode
exit code == 0, project == null        -> BACKLOG.md mode
exit code == 0, project == "KEY"       -> issue tracker mode with KEY
```

Decision tree:
- `issue-tracker-check` fails (non-zero exit) → **BACKLOG.md mode**
- `issue-tracker-check` succeeds and `"project"` is null (e.g., `{"ok":true,"project":null}`) → **BACKLOG.md mode**
- `issue-tracker-check` succeeds and `"project"` is non-null (e.g., `{"ok":true,"project":"example-org/example-repo"}`) → **issue tracker mode** with that project key

#### Read Context

Read `.claude/CLAUDE.md` to understand project constraints, conventions, and stakeholder defaults.

#### Load Backlog

- **issue tracker mode**: Run `oj-helper issue-tracker-list --project PROJECT_KEY` to fetch open items as JSON. Parse to extract key, summary, status, priority.
- **BACKLOG.md mode**: Read `.claude/BACKLOG.md` and parse the markdown structure to extract item IDs, titles, priority, and status.

Select the highest-priority **unblocked** item. If the backlog is empty, prompt the user for input — do not fabricate work.

### Phase 2 — Classify (Triage)

Perform two-dimensional triage.

#### A. Execution Model

Score against the 4-criterion checklist:

1. Spans multiple technical domains?
2. Regulatory or compliance implications?
3. Could impact production stability?
4. Significant cost or resource commitment?

**Scoring**: 0-1 = Simple, 2-3 = Moderate, 4 = Complex.

**Mandatory escalation to Complex** (overrides score):
- Security vulnerability or architectural change
- PCI or regulatory scope
- Production stability risk
- Irreversible one-way doors

#### B. Stakeholder Identification

**Mandatory pair** (all tiers): Product + Tech.

**Domain signals**:

| Signal | Add Stakeholder |
|--------|-----------------|
| Security / compliance | Security |
| Data modeling / pipelines | Data |
| Cross-system integration | Architecture |
| Infrastructure / CI-CD | Operations |
| Statistics / experimentation | Analytics |
| ML systems / model serving | ML |
| Test strategy / quality | Quality |
| SLOs / reliability | Reliability |
| Requirements / process | Business |

**Stakeholder escalation guard**:
- Simple with **4+** stakeholders → consider Moderate
- Moderate with **5+** stakeholders → consider Complex

#### C. Confirm Tier

Present the triage result to the user via `AskUserQuestion`. Offer three options with the recommended tier marked:

- **Simple** — Manager applies stakeholder perspectives inline using compact profiles
- **Moderate** — Task tool: parallel stakeholder analysis → lead implementation → adversarial review
- **Complex** — TeamCreate swarm with coordinator and parallel stakeholder agents

If the user overrides the recommendation, use their selection.

#### D. Issue Tracker Transition

**issue tracker mode only**: Run `oj-helper issue-tracker-transition KEY --status "In Progress"`. If the transition fails, log the failure and continue — issue tracker errors are non-blocking.

### Phase 3 — Plan & Execute

#### Plan Stakeholder Engagement

Before spawning any agents, declare the engagement plan:

1. Identify stakeholders from Phase 2B
2. Map each stakeholder to an agent profile using `${CLAUDE_PLUGIN_ROOT}/agents/index.md` and `${CLAUDE_PLUGIN_ROOT}/reference/stakeholder-guide.md`
3. Choose the plan for the selected execution model:
   - **Simple**: Manager applies perspectives inline using compact profiles (no agent spawns)
   - **Moderate**: Three-phase Task tool flow (parallel stakeholder analysis → lead implementation → adversarial review)
   - **Complex**: Team formation via `TeamCreate` — coordinator + stakeholder agents
4. State the plan explicitly: list each stakeholder, the agent assignment (or "inline"), and the expected deliverable

#### Execute — Simple (Inline Perspective Rotation)

Manager applies each stakeholder lens using compact profiles. For each stakeholder, produce:

```
PERSPECTIVE: [Stakeholder] ([profile].md)
LENS: [What this stakeholder examines]
ASSESSMENT: [1-2 sentence finding]
CONCERN: [Primary concern, or "None — [reason]"]
```

After all perspectives, synthesize into a unified action. If code changes are required, delegate implementation to the appropriate expert via the Task tool — the manager does not edit code directly.

#### Execute — Moderate (Task Tool, 3 Phases)

All three phases are mandatory.

- **Phase 1 — Stakeholder Analysis**: Spawn stakeholder agents in parallel via the Task tool. Analysis only; no implementation.
- **Phase 2 — Lead Implementation**: Synthesize Phase 1 findings, brief the lead expert with the synthesis, lead produces the deliverable.
- **Phase 3 — Adversarial Review**: Spawn a reviewer with the Adversarial Review Protocol — find the single most important problem, test documented failure modes.

#### Execute — Complex (Parallel Team / Swarm)

After tier classification confirms Complex, run `oj-helper agent-teams-check` and parse `.available` from the JSON stdout. The probe always exits 0 (Axiom 8 — capability report, not a precondition gate); branch on the JSON value, not the exit code.

*When `.available == true` — TeamCreate path:*

1. **Team Formation**: `TeamCreate` with coordinator + stakeholder agents
2. **Deputy Coordinator**: A general-purpose agent briefed with the full stakeholder plan; manages inter-stakeholder communication, task creation, and synthesis; keeps the manager's context lean
3. **Parallel Execution**: Stakeholders work concurrently, coordinated by the deputy
4. **Synthesis**: Coordinator synthesizes → manager reviews → user checkpoints at decision points
5. **Teardown**: Retrospective → `shutdown_request` to each teammate → `TeamDelete`

*When `.available == false` — Convene→Consult fallback (Axiom 8):*

1. **Deputy Spawn (via Task tool)**: Spawn ONE general-purpose deputy coordinator via the Task tool, briefed with the full stakeholder plan. `TeamCreate` is unavailable in this branch.
2. **Parallel Stakeholder Consults (via Task tool)**: The deputy fans out the stakeholder analyses as parallel Task-tool invocations.
3. **Handback-only Synthesis**: The deputy synthesizes via the handback protocol only — `SendMessage` / Inform is unavailable.
4. **Quality Gates Preserved**: User Checkpoint, pre-mortem (≥3 scenarios), and adversarial review remain mandatory.
5. **Teardown**: Retrospective only. Do NOT call `TeamDelete` or `shutdown_request` — those tools are unavailable in this branch.

*Runtime backstop (the probe is a hint, not a guarantee)*: `agent-teams-check` only inspects the env var; an environment where the var is set but `TeamCreate` is actually disabled at runtime (enterprise policy, future flag retirement) will steer this skill onto the team branch incorrectly. If the team branch is taken and the first `TeamCreate` call — or any agent-teams-gated tool (`TeamCreate`, `TeamDelete`, `SendMessage`, `shutdown_request`) — raises "Unknown tool" / "tool unavailable" at runtime, do NOT abort the task. Fall through to the deputy-coordinator parallel-Task-tool fan-out above (handback-only synthesis, no Inform). The runtime signal is authoritative over the probe; the User Checkpoint promised at triage MUST still fire before Phase 4.

### Phase 4 — Deliver

#### Test

Validate with tests. Prefer a balanced pyramid (unit > integration > e2e). Run existing tests to confirm no regressions before committing.

#### Commit

Create atomic commits with clear, focused messages.

> **No "Co-Authored-By" lines or AI attribution.** Omit Claude ads from commit messages.

**Verification gate**: After committing, run `git status`. If uncommitted changes remain (modified tracked files or untracked files created during the cycle), stage and commit them with a descriptive message. Perform only **one** verification pass.

#### Update Backlog

- **issue tracker mode**:
  - Transition to "Done": `oj-helper issue-tracker-transition KEY --status "Done"`. If it fails, note the ticket key and desired status for manual resolution and continue.
  - Add completion comment: `oj-helper issue-tracker-comment KEY --body "Completed: [summary]"`
  - Create tickets for any discovered work: `oj-helper issue-tracker-create --summary "..." --description "..."`
- **BACKLOG.md mode**:
  - Mark completed items
  - Add discovered work with priority and (if applicable) "Blocked By" notes
  - Write back to `.claude/BACKLOG.md`

### Phase 5 — Learn

#### Retrospective

Run a brief retrospective on what worked and what to improve. For **Complex** tier items, write a full retrospective to `.claude/archive/retros/` using the `retrospective.md` template.

#### Dev Mode Feedback

Run `oj-helper feedback-path` in bash:
- If the output is empty, dev mode is off — skip feedback
- If the output is a file path, write a feedback file at that path using the format below

```markdown
---
date: YYYY-MM-DD
item: KEY-NNN or BACK-XXX
tier: Simple|Moderate|Complex
---
### What Worked
- [bullet points]
### What to Improve
- [bullet points]
### OpenJunto System Suggestions
- [specific suggestions for improving OpenJunto itself]
```

Fill in the actual date, the ticket key (issue tracker mode) or backlog ID (BACKLOG.md mode), the tier, and the retrospective content. Each cycle produces exactly one new file.

#### Artifacts

Store design documents, ADRs, or analysis artifacts produced during the cycle in `.claude/artifacts/`.

#### Notify

Tell the user the cycle is complete, summarize what was done, and suggest `/clear` before the next cycle if context has grown large.

## Constraints

- **One item per cycle** — scope to exactly ONE backlog item to keep changes bounded and reviewable
- **Atomic commits** — prefer small, focused commits over large monolithic ones
- **Don't proceed past review** if peer review identifies blocking issues — iterate or escalate
- **Stop and ask** if blocked or uncertain — never guess
- **Issue tracker failures are non-blocking** — if the issue tracker is unreachable mid-cycle, complete the work and note the ticket key and status update needed for manual reconciliation
- **Delegation boundary** — the manager coordinates and synthesizes but does not implement; all code, documentation (except `.claude/BACKLOG.md`), and expert deliverables come from sub-agents
