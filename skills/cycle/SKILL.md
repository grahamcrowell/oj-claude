---
description: Execute the autonomous backlog cycle — triage, delegate, review, test, commit, retrospect
---

Execute against the backlog leveraging the team of expert agents.

## Backlog 

Read `.claude/BACKLOG.md` as the backlog source.

## Cycle Protocol

### Step 1 — Read Context
Read `.claude/CLAUDE.md` to understand project constraints.

### Step 2 — Load Backlog

Read `.claude/BACKLOG.md`. If empty, prompt the user for input.

Select the highest-priority unblocked item.

### Step 3 — Triage
Perform two-dimensional triage (see CLAUDE.md § Two-Dimensional Triage):

**A. Execution Model** — Apply the 4-criterion checklist:

| # | Criterion | Check |
|---|-----------|-------|
| 1 | Spans multiple technical domains? | [ ] |
| 2 | Regulatory or compliance implications? | [ ] |
| 3 | Could impact production stability? | [ ] |
| 4 | Significant cost or resource commitment? | [ ] |

Score: 0-1 = Simple, 2-3 = Moderate, 4 = Complex. Check mandatory escalation triggers (security vulnerability/architecture change, PCI/regulatory, production stability risk, irreversible one-way doors) — these override scoring to Complex.

**B. Stakeholder Identification** — Identify which perspectives must be represented:
- **Mandatory pair (all tiers)**: Product + Tech.
- **Domain signals**: Scan the task for triggers — Security/compliance, Data modeling/pipelines, Cross-system integration, Infrastructure/CI-CD, Statistics/experimentation, ML systems, Test strategy/quality, SLOs/reliability, Requirements/process. Add the corresponding stakeholder for each signal detected.
- **Stakeholder escalation guard**: Simple with 4+ stakeholders → consider Moderate. Moderate with 5+ stakeholders → consider Complex. Many stakeholders needing deep analysis is itself a complexity signal.

> Full stakeholder mapping with profiles and key questions: `${CLAUDE_PLUGIN_ROOT}/reference/stakeholder-guide.md`

Output BOTH the execution model classification AND the stakeholder list before proceeding.

### Step 4 — Plan Stakeholder Engagement
Before spawning any agents, declare the engagement plan:
1. **Identify stakeholders**: Use the stakeholder list from Step 3. Map each stakeholder to an agent profile using `${CLAUDE_PLUGIN_ROOT}/agents/index.md` and the Stakeholder Guide (`${CLAUDE_PLUGIN_ROOT}/reference/stakeholder-guide.md`).
2. **Plan by execution model**:
   - **Simple**: Manager will apply stakeholder perspectives inline using compact profiles (`${CLAUDE_PLUGIN_ROOT}/agents/*-compact.md`). No agents spawned for analysis — the manager rotates through each lens directly.
   - **Moderate**: Plan Phase 1 (stakeholder analysis agents spawned in parallel), Phase 2 (lead implementation agent), Phase 3 (adversarial reviewer). Assign a profile to each phase.
   - **Complex**: Plan team formation — coordinator + stakeholder agents via `TeamCreate`. Identify the deputy coordinator role and assign stakeholder agents to parallel workstreams.
3. **State the plan**: Name each stakeholder perspective, their agent assignment (or "inline" for Simple), and expected deliverable before proceeding to execution.

### Step 5 — Execute
Execute according to the execution model determined in Step 3 (see CLAUDE.md § Execution Models):

**Simple — Inline Perspective Rotation**:
The manager applies each identified stakeholder lens directly using compact profiles (`${CLAUDE_PLUGIN_ROOT}/agents/*-compact.md`). For each stakeholder, produce a PERSPECTIVE block:
```
PERSPECTIVE: [Stakeholder] ([profile].md)
LENS: [What this stakeholder examines]
ASSESSMENT: [1-2 sentence finding]
CONCERN: [Primary concern, or "None — [reason]"]
```
After all perspectives: synthesize into unified action. If code changes are needed, delegate implementation to an expert agent via the Task tool.

**Moderate — Task Tool Engagement (3 phases)**:

*Phase 1 — Stakeholder Analysis*: Spawn stakeholder analysis agents in parallel. Each agent examines the task from their stakeholder perspective. These agents analyze but do NOT implement.

*Phase 2 — Lead Implementation*: Synthesize Phase 1 findings. Brief the lead expert with the synthesized stakeholder analysis. The lead expert produces the primary deliverable.

*Phase 3 — Adversarial Review*: Spawn the reviewer with the Adversarial Review Protocol. The reviewer's job is to find the single most important problem. Peer review is integrated here — there is no separate review step.

All three phases are mandatory for Moderate tier.

**Complex — Parallel Team (Swarm)**:

1. **Team Formation**: Create the team via `TeamCreate`. Spawn a deputy coordinator and stakeholder agents as teammates.
2. **Deputy Coordinator**: A general-purpose agent briefed with the full stakeholder plan. Manages inter-stakeholder communication, creates tasks, synthesizes raw output, and relays concise updates to the manager.
3. **Parallel Execution**: Stakeholder agents work concurrently, coordinated by the deputy.
4. **Synthesis**: Coordinator synthesizes → manager reviews → user checkpoints as needed.
5. **Teardown**: Retrospective, then `TeamDelete` to clean up the team.

### Step 6 — Test
Validate with tests. Ensure a balanced test pyramid (unit > integration > e2e). Run existing tests to confirm no regressions.

### Step 7 — Commit
Create atomic commits with clear messages. Do NOT include "Co-Authored-By" lines or other AI attribution in commit messages.

**Commit Verification Gate** (7a): After committing, run `git status` to confirm the working tree is clean — no uncommitted tracked changes or untracked files that should be committed. If uncommitted changes remain, stage and commit them before proceeding. Do not advance to Step 8 until the working tree is clean.

### Step 8 — Update Backlog
- **BACKLOG.md**: Mark completed items, add any discovered work, update `.claude/BACKLOG.md`.

### Step 9 — Retrospective
Brief retrospective on what worked and what to improve. For Complex tier items, write to `.claude/archive/retros/`.

**Dev Mode Feedback** (9a): Run `oj-helper feedback-path` in bash. If the output is empty (dev mode is off), skip feedback. Otherwise, the output is the file path to write. Write the feedback file to that path with this format:
```
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
- [specific suggestions for improving OpenJunto itself — agent profiles, cycle protocol, CLAUDE.md instructions, etc.]
```
Fill in the actual date, backlog item ID (BACKLOG.md), tier, and retrospective content from this cycle. Each cycle produces exactly one new file.

### Step 10 — Artifacts
Store any design documents, ADRs, or analysis artifacts in `.claude/artifacts/`.

### Step 11 — Notify
Tell the user the cycle is complete, summarize what was done, and suggest `/clear` before the next cycle if context is getting large.

## Constraints

- Scope each cycle to ONE backlog item to keep changes bounded and reviewable.
- Prefer small, atomic commits over large monolithic ones.
- Do not proceed past review if peer review identifies blocking issues.
- If blocked or uncertain, stop and ask the user rather than guessing.
