# Execution Protocol

Full execution mechanics for the OpenJunto manager protocol. The always-injected CONDUCTOR.md carries only the CORE (role, constraints, triage, stakeholder selection, and a one-paragraph-per-tier overview). This file holds the heavy machinery the manager needs once it is actually executing a Moderate or Complex item.

**Load this file just-in-time**: before executing any Moderate or Complex work, load `${CLAUDE_PLUGIN_ROOT}/reference/execution-protocol.md`. Trivial and Simple tiers do not require it — their full behavior is specified in the CONDUCTOR CORE.

---

## Execution Models

### Simple: Inline Perspective Rotation

The manager applies each identified stakeholder lens directly using compact profiles (`${CLAUDE_PLUGIN_ROOT}/reference/compact/<name>.md`).

For each stakeholder, produce:

```
PERSPECTIVE: [Stakeholder] ([profile].md)
LENS: [What this stakeholder examines]
ASSESSMENT: [1-2 sentence finding]
CONCERN: [Primary concern, or "None — [reason]"]
```

After all perspectives: synthesize into unified action. For code changes, delegate implementation to an expert agent.

> This is the explicit exception to the delegation boundary. The forcing function is mandatory PERSPECTIVE documentation — every identified stakeholder must produce a block before action.

### Moderate: Task Tool Engagement

**Phase 1 — Stakeholder Analysis** (spawn in parallel):

```
<!-- oj-expert: [profile-filename] -->
You are a [Stakeholder Role].
**TASK**: Analyze [aspect] from your stakeholder perspective. Focus on [questions]. Do NOT implement — analysis only.
```

**Synthesis Gate**: Before spawning the implementer, consolidate stakeholder output into a findings ledger (FINDING/TENSION lines). TENSION items are PROTECTED — they cannot be removed during synthesis and must be forwarded to the implementer and reviewer. If the ledger contains `CONFIDENCE: Low` on a named key assumption, pause and present findings to the user before proceeding.

**Phase 2 — Lead Implementation** (after synthesis):

```
<!-- oj-expert: [lead-profile] -->
You are a [Lead Role].
**TASK**: Implement [deliverable]. Stakeholder analysis:
- [Stakeholder 1]: [synthesized findings]
- [Stakeholder 2]: [synthesized findings]
```

The implementer must complete a pre-mortem (≥2 failure scenarios, state mitigation or accepted risk for each) before producing the work product.

**Phase 3 — Adversarial Review**:

```
<!-- oj-expert: [reviewer-profile] -->
You are a [Reviewer Role].
**TASK**: Adversarial review. Find the single most important correctness- or requirements-affecting problem. Ignore stylistic and preferential concerns. Test: [failure modes]. If you find no material problem, explain specifically why this work is resistant to the failure modes you tested.
```

**Reviewer scope**: The reviewer flags ONLY gaps that affect correctness or requirements — behavior that is wrong, unsafe, or that fails to meet a stated requirement. Stylistic or preferential concerns (naming taste, formatting, alternative-but-equivalent approaches) are OUT of scope and must NOT be raised as review findings. "No material concerns" is an acceptable outcome at ALL tiers when the reviewer tests specific failure modes and finds no correctness- or requirements-affecting gap — the correct verdict is then "None — resistant because [specific reasoning]", not a manufactured problem. This does NOT remove the obligation to run the review or to emit the FAILURE MODES TESTED section; the reviewer still runs and still documents what was probed.

*Design intent (Axiom 3 — Adversarial Mechanisms)*: LLMs default to coherent affirmation. STRONGEST OBJECTION and FALSIFIER fields, and a distinct adversarial reviewer, are mandatory forcing functions for critique.

> Full adversarial-review output format (FAILURE MODES TESTED, #1 PROBLEM FOUND, ADDITIONAL CONCERNS, CONFIDENCE CALIBRATION, VERDICT): `${CLAUDE_PLUGIN_ROOT}/reference/workflow-stages.md`.

### Complex: Parallel Team (Swarm)

1. **Team Formation**: `TeamCreate` → spawn coordinator + stakeholder agents (target 3-5 teammates, 5-6 tasks each). Requires `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`.
2. **Deputy Coordinator**: a general-purpose agent briefed with the full stakeholder plan. Manages inter-stakeholder communication, creates tasks, synthesizes raw output, relays concise updates to the manager. Keeps the manager's context lean; does not make high-level decisions or interact with the user directly.
3. **Task Structure**: analysis tasks are unblocked and parallel; implementation `blockedBy` analysis; review `blockedBy` implementation. Teammates self-claim via `TodoWrite`, prefer lowest ID.
4. **Plan Approval**: use `plan_mode_required: true` for high-stakes implementation/review. Coordinator reviews plans before execution via `plan_approval_response`.
5. **Quality Gate Hooks**: pre-mortem (≥3 scenarios across technical/operational/organizational/business), adversarial review with failure-modes-tested section, steelman of top 1-2 rejected alternatives, User Checkpoint — asks **"Should we proceed?"** before final synthesis; cannot be skipped.
6. **Structured Shutdown**: retrospective (coordinator or manager leads) → `shutdown_request` to each teammate → await `shutdown_response` → `TeamDelete` (fails if active members remain).
7. **File Conflict Avoidance**: use git worktrees for overlapping file edits (isolated working directories, shared git history).

**Fallback (Axiom 8 — graceful degradation)**: When `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` is unset (or the host environment otherwise disables the agent-teams feature), `TeamCreate`, `TeamDelete`, `shutdown_request`, and `SendMessage` are unavailable. In that case, Complex tier degrades to a **deputy-coordinator parallel-Task-tool fan-out**:

1. Run `oj-helper agent-teams-check` and parse `.available` from the JSON stdout. The probe always exits 0 — read `.available`, not the exit code.
2. When `.available == true`: proceed with `TeamCreate` exactly as steps 1-7 above describe.
3. When `.available == false`: spawn ONE general-purpose deputy coordinator via the Task tool, briefed with the full stakeholder plan. The deputy fans out the stakeholder analyses as parallel Task-tool calls and synthesizes via the handback protocol only (no `SendMessage` peer relay, no `TeamCreate`, no `TeamDelete`, no `shutdown_request`).
4. User Checkpoint (Stage 8 / Quality Gate; "Should we proceed?"), pre-mortem (≥3 scenarios across technical/operational/organizational/business), and adversarial review remain mandatory. The fallback is an execution-substrate degradation, NOT a tier downshift — every Complex quality gate fires.
5. **Runtime backstop (the probe is a hint, not a guarantee)**: `agent-teams-check` reads only the env var; an environment where the var is set but `TeamCreate` is in fact disabled (enterprise policy, future flag retirement) will report `available:true` and steer the manager onto the team branch incorrectly. If the team branch is taken and the first `TeamCreate` (Convene) call fails — or any agent-teams-gated tool (`TeamCreate`, `TeamDelete`, `SendMessage`, `shutdown_request`) raises "Unknown tool" / "tool unavailable" at runtime — do NOT abort the item. Fall through to step 3 above (the deputy-coordinator parallel-Task-tool fan-out, handback-only synthesis, no Inform). The runtime signal is authoritative over the probe; the User Checkpoint promised at triage MUST still fire.

The manager focuses on high-level decisions and user interaction. The coordinator handles operational coordination.

---

## Handback Protocol

### Simple Tier Format

Compressed format (~5 lines):

```
HANDBACK: [Role] | STATUS: [Complete|Iterate|Blocked|Escalate] | CONFIDENCE: [High|Med|Low]
DELIVERABLE: [What was produced]
RECOMMENDATION: [1-2 sentences including rationale]
STRONGEST OBJECTION: [Best counterargument]
NEXT: [Actions]
```

### Moderate/Complex Tier Format

Full format (9 fields):

```
HANDBACK: [Expert Role]
STATUS: [Complete | Needs Iteration | Blocked | Escalate]
DELIVERABLE: [What was produced]
RECOMMENDATION: [Primary recommendation in 1-2 sentences]
RATIONALE: [Key reasoning]
STRONGEST OBJECTION: [Best argument against this recommendation]
FALSIFIER: "Fails if [condition] because [mechanism]."
CONFIDENCE: [High | Medium | Low]
CAVEATS: [Assumptions, limitations]
NEXT ACTIONS: [Actionable items]
```

### Field Definitions

**STRONGEST OBJECTION** is rhetorical: the best argument against the recommendation. Required for Moderate/Complex. A good one makes you briefly reconsider — if it doesn't, you haven't found the strongest counterargument. Genuinely engage the strongest counterargument rather than inventing a weak one.

**FALSIFIER** is empirical: "Fails if [condition] because [mechanism]." Required for Moderate/Complex. Names the specific condition and mechanism that would invalidate the recommendation — enabling downstream verification rather than rhetorical debate.

### Status Definitions

| Status | Meaning | Manager Response |
|--------|---------|------------------|
| **Complete** | Meets acceptance criteria | Peer review or synthesis |
| **Needs Iteration** | Gaps identified, path clear | Re-engage with clarified scope |
| **Blocked** | Requires external input | Escalate to user or other expert |
| **Escalate** | Scope change discovered | Re-triage, additional experts |

### Confidence Definitions

| Confidence | Signals | Manager Action |
|------------|---------|----------------|
| **High** | Proven patterns, low ambiguity | Light verification |
| **Medium** | Assumptions need validation | Peer review, verify assumptions |
| **Low** | Significant uncertainty | Additional experts, user checkpoint |

### Calibration Challenge

Low confidence is valuable signal, not failure. For High confidence claims the reviewer probes: *"What would drop this to Medium?"* The expert must answer with specific conditions.

---

## Quality Gates

### Simple Tier (2 items)
- [ ] Directly addresses the original question
- [ ] All identified stakeholder perspectives documented (PERSPECTIVE blocks)

### Moderate Tier (6 items)
- [ ] Directly addresses the original question
- [ ] All identified stakeholder perspectives represented
- [ ] Assumptions explicitly stated
- [ ] At least one risk identified (or adversarial analysis finding no material concerns)
- [ ] Adversarial review completed (failure modes tested and documented; "no material concerns" is an acceptable, well-supported outcome)
- [ ] Pre-mortem conducted

### Complex Tier (9 items)
- [ ] Directly addresses the original question
- [ ] All identified stakeholder perspectives represented
- [ ] Assumptions explicitly stated with risks and mitigations
- [ ] Adversarial review by cross-functional stakeholders (failure modes tested and documented; "no material concerns" is an acceptable, well-supported outcome)
- [ ] Dissenting views documented (even if overruled)
- [ ] Success criteria defined
- [ ] Pre-mortem conducted (3+ failure scenarios)
- [ ] Rejected alternatives steelmanned
- [ ] Retrospective completed

> The review gate flags only correctness/requirements-affecting gaps. A clean review with a well-supported "no material concerns" verdict passes the gate provided the FAILURE MODES TESTED section is populated — do not force the reviewer to manufacture an objection.

---

## Agent Spawning

### Spawning Pattern

A `SubagentStart` hook (`oj-helper inject-profile`) automatically injects the expert preamble and full profile into sub-agents at spawn time. The manager does NOT need to paste profiles inline or instruct experts to read their own profiles.

**All tiers** — include the `oj-expert` marker and task description:

```
<!-- oj-expert: [profile-filename] -->
You are a [Expert Role Name].
**TASK**: [Task, context, and expected deliverable]
```

The `<!-- oj-expert: ... -->` marker tells the hook which profile to inject. Use the profile filename without extension (e.g., `senior-software-engineer`, `senior-distinguished-engineer`). The hook injects `${CLAUDE_PLUGIN_ROOT}/reference/expert-preamble.md` + the full profile from `${CLAUDE_PLUGIN_ROOT}/agents/` as `additionalContext`.

**Context inheritance**: Sub-agents automatically inherit the user-global `CLAUDE.md` and the project-local `.claude/CLAUDE.md` as `<system-reminder>` context. They do NOT inherit conversation history or session state. No additional context injection is needed for standard protocol compliance.

**Fallback**: If the hook is unavailable (e.g., `oj-helper` not in PATH, `jq` missing, or profile not found), the expert receives no injected profile. In that case, add self-loading instructions to the spawn prompt:

```
You are a [Expert Role Name].
**FIRST**: Read `${CLAUDE_PLUGIN_ROOT}/reference/expert-preamble.md` and your full profile at `${CLAUDE_PLUGIN_ROOT}/agents/[profile-filename].md`.
**THEN**: [Task, context, and expected deliverable]
```

**Expert orientation** — every expert's first output line must be a one-line orientation statement:
- **Analyst**: "Primary concern from my domain: [X]"
- **Implementer**: "Highest-risk constraint: [X]"
- **Reviewer**: "Weakest current claim: [X]"

### Model Selection

Set the `model` parameter on Task tool spawns to match the task's cognitive demand. Sub-agents inherit the manager's model (typically `fable`) if unset — set it explicitly on every spawn; inheriting `fable` is the expensive failure mode. Spawns inherit the session effort — run oj sessions at **`high`** (see Effort below).

| Model | When to Use | Examples |
|-------|-------------|----------|
| **sonnet** (tier: routine, cost ratio 0.6×) | Stakeholder analysis compressed to FINDING/TENSION, bounded or compact lenses, mechanical checks | Phase-1 stakeholder analysis, docs-only review, conformance checks, backlog item text |
| **opus[1m]** (tier: implementation, cost ratio 1.0×) | Routine edits, mechanical transforms, implementation with clear requirements | Doc updates, boilerplate, search-and-replace across files, feature implementation from a spec, code review, test writing |
| **fable** (tier: reasoning, cost ratio 2.0×) | Ambiguous problems, architectural decisions, novel design | System design, complex debugging, adversarial review, cross-domain synthesis |

When in doubt, use the more capable model (sonnet < opus[1m] < fable).

#### Function-First Selection Rules

Pick the model per spawn by the spawn's **function** (what the role is doing in this engagement), with per-role defaults as a secondary anchor. The function rules below override the role-default table when they conflict — a role's default tier is the floor for routine engagements, not a ceiling on adversarial or high-risk ones.

- **Adversarial reviewer slot (any role)** → **fable**. The reviewer's output is forwarded verbatim and must break the work; it is the load-bearing critique surface and should run on the strongest tier regardless of the reviewer's default.
- **Complex-tier lead implementer** → **fable**. Complex-tier work is by definition ambiguous, cross-domain, or high-blast-radius; the lead carries the synthesis weight.
- **Moderate-tier lead implementer** → **opus[1m]** by default; escalate to **fable** when the implementation is high-risk (novel design, security-sensitive, irreversible migration, or the findings ledger contains an unresolved TENSION the lead must arbitrate).
- **Phase-1 stakeholder analysts (output compressed to FINDING / TENSION)** → **sonnet**, including bounded or lightweight lenses (e.g., docs-only review, mechanical conformance checks). Their output is compressed before it reaches the implementer — the marginal accuracy of a stronger tier is not load-bearing here.
- **Specialists engaged on a domain trigger** → **opus[1m]** by default; escalate to **fable** when their domain is the **decisive risk** for the engagement (e.g., Security on an auth/crypto change, SRE on an SLO-impacting change, Data Architect on a destructive migration).

#### Fan-Out Budget

Wide fan-outs are the dominant quota risk — a single research cycle that spawns dozens of agents can exhaust a 5-hour usage window on its own. Research/explain engagements should prefer Simple-tier inline perspective rotation, or cap parallel spawns at **~10 per cycle**. Reserve wider fan-outs for Complex-tier engagements where the parallelism is load-bearing, and prefer sequential depth (one agent following a thread) over breadth when the questions are dependent.

#### Per-Role Default Model (adjustable; function rules always win)

These are **starting defaults** for the role when no function rule applies. Treat them as adjustable per engagement — the function rules above always take precedence when any of them applies (reviewer-slot, Complex-tier lead, Moderate-tier lead, Phase-1 analyst, or domain-trigger specialist). The per-role default below fires only when no function rule matches the spawn.

| Default Model | Roles |
|---------------|-------|
| **fable** | Distinguished Engineer, Security Engineer, Site Reliability Engineer, Engineering Consultant |
| **opus[1m]** | Software Engineer, Solutions Architect, DevOps Engineer, Test Engineer, Data Architect, Data Scientist, ML Engineer, Enterprise Architect |
| **sonnet** | Business Analyst, Product Manager, Executive Leadership Coach, Technical Writer |

Anchor example: `${CLAUDE_PLUGIN_ROOT}/reference/worked-examples.md` Example 2 (Moderate-tier rate-limiting) sets `model: sonnet` on the stakeholder analysts, `model: opus[1m]` on the lead implementer, and `model: fable` on the adversarial reviewer — the function rules above are the general form of that pattern.

Second anchor (reviewer-slot wins regardless of role default): a Senior Technical Writer (role default: `sonnet`) or a Senior Software Engineer (role default: `opus[1m]`) spawned as the adversarial reviewer runs on **`fable`** — the reviewer-slot rule wins over the role default. The reviewer slot is `fable` because of its function, not because of the reviewer's role; do not read Example 2's Security-Engineer-on-`fable` reviewer as that role's default.

#### Effort

Spawns inherit the session effort — run oj sessions at **`high`**, and escalate the session to `xhigh` only for Complex-tier engagements (the user's `/effort` setting applies session-wide). On the current model generation, `high` retains near-ceiling accuracy while materially cutting thinking-token spend and turn latency; `xhigh` is the opt-in for the hardest work, not the default. Per-expert effort is not controllable in the current architecture: expert profiles are injected into `general-purpose` Task spawns via the `SubagentStart` hook (`oj-helper inject-profile`), and that spawn surface exposes no per-invocation effort knob — frontmatter on `${CLAUDE_PLUGIN_ROOT}/agents/*.md` is a no-op because the Task tool does not read those files as subagent definitions. Do not fabricate per-expert effort control; per-expert effort tiering would require re-architecting experts as native, distinct subagent types — defer.

*Design intent (Axiom 4 — Token Efficiency)*: compact profiles at Simple tier, tier-aware context loading, output compression, and model selection by cognitive demand keep routine work cheap so that Complex work can afford maximum scrutiny.

---

## Definition of Done

### Simple Tier
- User question answered
- All PERSPECTIVE blocks documented
- No outstanding blockers

### Moderate Tier
- All Quality Gates passed
- User has received deliverable
- No unresolved peer review concerns

### Complex Tier
- All Quality Gates passed
- User has explicitly approved deliverable
- Retrospective completed
- Action items assigned owners

### Verifying Deliverables

Before reporting work complete, the Manager must verify:
1. **Output exists** — Check that expected files/artifacts were actually created
2. **Output looks correct** — For visual work (screenshots, UI), inspect the actual result
3. **Output differs from baseline** — For updates, confirm the change is visible

Never accept an agent's claim of "done" without verification.

### Incorporating Lessons

**Update .claude/CLAUDE.md when**: pattern repeats 2-3 times, OR high-severity (security/data loss), AND fix is a clear actionable rule. **Don't update for**: one-time errors, common sense, or duplicate guidance. Most lessons don't need persisting.

---

## Reference and Operations

### issue tracker Bootstrap

If `${CLAUDE_PLUGIN_ROOT}/reference/issue-tracker-integration.md` exists (installed by enterprise overlay), read it before any issue tracker operation. Always run `oj-helper issue-tracker-check` as the first issue tracker operation in any session.

### Tier-Aware Context Loading

| Tier | What to Load |
|------|-------------|
| **Trivial** | Nothing beyond the always-injected CORE |
| **Simple** | Compact profiles inline (auto or from `${CLAUDE_PLUGIN_ROOT}/reference/compact/`) |
| **Moderate** | Full profiles (hook-injected) + `${CLAUDE_PLUGIN_ROOT}/reference/execution-protocol.md` + `${CLAUDE_PLUGIN_ROOT}/reference/workflow-stages.md` + `${CLAUDE_PLUGIN_ROOT}/reference/stakeholder-guide.md` |
| **Complex** | Full profiles (hook-injected) + `${CLAUDE_PLUGIN_ROOT}/reference/execution-protocol.md` + ALL reference files |

### Reference Files

| File | Content |
|------|---------|
| `execution-protocol.md` | Full execution mechanics: execution models, handback protocol, quality gates, agent spawning (model selection, fan-out budget, effort), definition of done, reference and operations |
| `workflow-stages.md` | Tier workflows, pre-mortem gate, adversarial review protocol |
| `stakeholder-guide.md` | Stakeholder mapping, disagreement protocol, steelman |
| `worked-examples.md` | End-to-end examples for all three tiers |
| `dev-mode.md` | Dev mode feedback collection |
| `failure-protocol.md` | Sub-agent failure handling |
| `file-patterns.md` | Backlog management, LLM-optimized patterns, project structure |
| `project-scaffolding.md` | Session state, carry-over, context maps, artifact org, caching, comms |
| `communication-standards.md` | Technical communication standards, anti-patterns |

> **Organization-specific reference**: Additional files in `${CLAUDE_PLUGIN_ROOT}/reference/` may be installed by the enterprise overlay (e.g., issue tracker integration, AWS CLI patterns, CI/CD patterns, organizational standards). Check the directory for available files.

### Templates

| Template | File | When to Use |
|----------|------|-------------|
| **Technical Analysis** | `technical-analysis.md` | Investigations, evaluations |
| **Architecture Decision Record** | `architecture-decision-record.md` | Significant technical decisions |
| **Retrospective** | `retrospective.md` | Complex tier post-engagement (required) |
| **Session State** | `session-state.md` | Volatile session layer — write to `oj-helper resolve-path session` (default `.claude/state/session.md`) |
| **Communications Playbook** | `communications-playbook.md` | `.claude/COMMS.md` signal gate + channel routing |
