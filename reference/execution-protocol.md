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
**TASK**: [The deliverable, in one sentence]
**FILES**: [Explicit paths to read. Not "the codebase", not "the repo".]
**QUESTION**: [The single decision this spawn exists to inform]
**OUT OF SCOPE**: [What not to explore]
**NON-GOAL**: Do not survey adjacent code. If the files listed are insufficient
to answer the question, say so and stop - do not go looking.
```

**The brief is the cost control, and `NON-GOAL` is the load-bearing line.** A sub-agent starts with a fresh context window, so whatever it ends up holding is what it read on its own initiative. An under-specified brief does not produce a cheap vague answer; it produces an expensive thorough one, because the expert compensates for the missing scope by exploring. Naming the files converts a hundred-turn investigation into a bounded read, and inviting the expert to fail fast converts the residual case into one cheap round trip instead of a long guess. Never pass accumulated session state down the chain in place of a scope.

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

### Model and Effort Selection

**Model and effort are properties of the role, declared in its own frontmatter.** Each profile in `${CLAUDE_PLUGIN_ROOT}/agents/` carries `model`, `effort`, and where appropriate `maxTurns` and `disallowedTools`. A spawn that omits `model` inherits the role's declaration, and **that is the intended behaviour** - not an oversight to correct. Pass `model` explicitly only to *override* the role default for one spawn (see Function-First Selection Rules below), never as boilerplate.

The roster splits into two **model classes**, keyed by what the role does rather than by how weighty its subject sounds:

- **authoring class** (`platform.model_policy.default_model`) - the role writes code or a durable artifact, so its turns produce the deliverable and capability is load-bearing. One role: Software Engineer.
- **advisory class** (`platform.model_policy.advisory_model`) - the role reads and forms a view, and that handback is compressed before anyone acts on it. Everyone else.

Evidence for splitting here rather than by seniority: across a 163-agent sample the advisory roles produced a file 6 times in 50 outings, while the authoring role wrote in 24 of 26. Reading code and forming a view costs the same whether the view is about security or about naming.

The class resolves to a concrete model in each role's frontmatter, which is the operator-editable surface. This prose names classes, not models, so that an adopter's procurement policy governs the values.

What still varies per spawn is **which spawns deserve the deepest attention**. The tier vocabulary below names that, and a tier names an effort level.

| Tier | Effort | Cognitive demand | Examples |
|------|--------|------------------|----------|
| **routine** (`high`) | `high` | Stakeholder analysis compressed to FINDING/TENSION, bounded or compact lenses, mechanical checks | Phase-1 stakeholder analysis, docs-only review, conformance checks, backlog item text |
| **implementation** (`xhigh`) | `xhigh` | Implementation with clear requirements, analysis with known patterns | Feature implementation from a spec, code review, test writing, multi-file refactor |
| **reasoning** (`max`) | `max` | Ambiguous problems, architectural decisions, novel design | System design, complex debugging, adversarial review, cross-domain synthesis |

No cost-ratio column: a tier's real cost is thinking-token spend, which is not a published constant, and it now compounds with the role's model. The ordering is what matters, and the ordering holds.

The roster, the tier-to-effort bindings, and the model policy are defined in `${CLAUDE_PLUGIN_ROOT}/platform-defaults.yaml` under `platform.models`, `platform.effort_tiers`, and `platform.model_policy` - the single source of truth. The tables here mirror it for inline guidance; when it changes, update that file (and re-render), not these tables.

When in doubt, use the higher tier.

#### Where Effort Actually Takes Effect

Effort resolves at two levels, and they are separate settings.

**Per expert, via frontmatter.** A subagent definition's `effort` field (`low` | `medium` | `high` | `xhigh` | `max`) overrides session effort for the duration of that spawn. The plugin's roles ship with this set. The Task/Agent tool still exposes no per-invocation effort argument, so a one-off override means editing the role or spawning a different one - but the per-role default is real configuration, not aspiration.

**Per session, for the manager's own turns**, set once at triage:

| Engagement tier | Session effort |
|-----------------|----------------|
| Simple | `high` |
| Moderate | `high` |
| Complex | `xhigh` |

Two notes on these values. They are one step below the tiers this table used to carry, because the model guidance for Claude Opus 5 is to *start* at `high` and step up only where evals show headroom - the `xhigh`-first advice belongs to Opus 4.7 and 4.8, and carrying it forward is the single most common source of unexamined spend. And effort affects **all** tokens including tool calls, so a lower setting produces fewer, more consolidated calls; it compounds into turn count, not just per-token depth.

**Do not raise session effort mid-run.** This reverses earlier guidance, for a mechanical reason: changing the effort value between requests **invalidates the prompt cache**, so a bump at turn 200 of a long session re-writes the entire prefix at cache-write price. If triage re-classifies an engagement upward, finish or stop the current invocation and start the next one at the higher setting. Vary effort across invocations, never within one. The setting is `effortLevel` in `settings.json`, equivalently the user's `/effort`.

#### Minimum-Effort Floor

A configurable floor sets the lowest tier any spawn may run at. It is defined in `${CLAUDE_PLUGIN_ROOT}/platform-defaults.yaml` under `platform.model_policy.min_effort_tier` (the single source of truth; this prose mirrors it and re-renders on a policy change). The value is a tier name - `routine`, `implementation`, or `reasoning` (ordering: routine < implementation < reasoning) - **currently `routine`**.

Apply the floor as the **last step** of selection, after the function-first rules and per-role defaults below have resolved a tier: if the resolved tier is below the floor, raise it to the floor; otherwise leave it unchanged. The floor is a lower bound only - it never lowers a selection, so every escalation (reviewer slot, Complex-tier lead, domain-decisive-risk specialist) still stands. With the floor at `routine` nothing is bumped. Raising it to `implementation` lifts routine spawns to `xhigh`; raising it to `reasoning` puts everything at `max`.

The floor applies to both places effort resolves: the role's declared `effort` and the engagement-tier-derived session effort. It was renamed from *minimum-model floor* because it governs reasoning depth; the model split is now carried by role frontmatter rather than by this floor.

#### Model Policy and the Adopter Override

`platform.model_policy` in `${CLAUDE_PLUGIN_ROOT}/platform-defaults.yaml` carries `default_model` plus `allowed_models` / `denied_models`. **Both lists ship empty, and that is deliberate.** This plugin is installed by other organizations; a model named in the shipped defaults would impose one org's procurement policy on everyone. The knob is generic, the value is not.

An operator sets policy for their own project in `<root>/.claude/oj-model-policy.env`, read at runtime by `oj-helper model-policy`:

```
denied_models=<api-id your org prohibits>
min_effort_tier=implementation
```

(The placeholder is intentional: writing a real model id here would leak one organization's policy into a document every adopter reads.)

That file lives in the adopter's repo, so it survives `/plugin` upgrades. Editing the installed `platform-defaults.yaml` does not work: the install is a read-only marketplace cache that upgrades replace, and nothing dereferences that YAML at runtime anyway - it is a generation-time input, and this prose is the behavioral surface.

Check a model before spawning with `oj-helper model-policy --check <api-id>` (exit 0 permitted, 1 denied). A deny wins over an allow; an empty `allowed_models` means "no allowlist", not "nothing permitted".

#### Function-First Selection Rules

Judge the **effort tier** a spawn warrants by its **function** (what the role is doing in this engagement), with per-role defaults as a secondary anchor. The function rules override the role-default table when they conflict - a role's default tier is the floor for routine engagements, not a ceiling on adversarial or high-risk ones.

- **Adversarial reviewer slot (any role)** -> **reasoning** (`max`). The reviewer's output is forwarded verbatim and must break the work; it is the load-bearing critique surface and warrants the deepest reasoning regardless of the reviewer's default.
- **Complex-tier lead implementer** -> **reasoning** (`max`). Complex-tier work is by definition ambiguous, cross-domain, or high-blast-radius; the lead carries the synthesis weight.
- **Moderate-tier lead implementer** -> **implementation** (`xhigh`) by default; escalate to **reasoning** (`max`) when the implementation is high-risk (novel design, security-sensitive, irreversible migration, or the findings ledger contains an unresolved TENSION the lead must arbitrate).
- **Phase-1 stakeholder analysts (output compressed to FINDING / TENSION)** -> **routine** (`high`), including bounded or lightweight lenses (e.g., docs-only review, mechanical conformance checks). Their output is compressed before it reaches the implementer, so extra reasoning depth is not load-bearing here.
- **Specialists engaged on a domain trigger** -> **implementation** (`xhigh`) by default; escalate to **reasoning** (`max`) when their domain is the **decisive risk** for the engagement (e.g., Security on an auth/crypto change, SRE on an SLO-impacting change, Data Architect on a destructive migration).

These rules resolve against the role's declared `effort`, and they are the documented reason to override it. Where a rule lands **above** the role default, promote the spawn: pass the authoring-class model on the Agent call and, if the depth genuinely matters, route it to a role whose frontmatter carries the higher effort. The adversarial reviewer slot is the case that matters most - it is the load-bearing critique surface, it is the one advisory spawn whose independence is doing real work, and it should be promoted to the authoring class even when the role behind it is an advisory one. Where a rule lands at or below the role default, spawn it plainly and let the frontmatter apply.

#### Fan-Out Budget

Wide fan-outs are the dominant quota risk — a single research cycle that spawns dozens of agents can exhaust a 5-hour usage window on its own. Research/explain engagements should prefer Simple-tier inline perspective rotation, or cap parallel spawns at **~10 per cycle**. Reserve wider fan-outs for Complex-tier engagements where the parallelism is load-bearing, and prefer sequential depth (one agent following a thread) over breadth when the questions are dependent.

#### Per-Role Default Tier (adjustable; function rules always win)

These are the values actually shipped in each role's frontmatter, which is the single source of truth - this table mirrors it, and if the two disagree the frontmatter wins and the divergence is a bug. The function rules above always take precedence when one applies (reviewer-slot, Complex-tier lead, Moderate-tier lead, Phase-1 analyst, or domain-trigger specialist); the defaults below fire when no function rule matches.

| Class | Model / effort | Bounds | Roles |
|-------|----------------|--------|-------|
| **authoring** | authoring class / `xhigh` | none - its turns produce code | Software Engineer |
| **advisory, may author** | advisory class / `high` | `maxTurns: 40` | Distinguished Engineer, Test Engineer, DevOps Engineer, Technical Writer |
| **advisory** | advisory class / `high` | `maxTurns: 30`, no `Write`/`Edit` | Business Analyst, Data Architect, Data Scientist, Engineering Consultant, Enterprise Architect, Executive Leadership Coach, ML Engineer, Product Manager, Security Engineer, Site Reliability Engineer, Solutions Architect |

The middle class exists because those four roles were observed producing a durable artifact often enough that denying them `Write` would break real work; they are capped but not blocked. A role moves down into the bottom class once its handbacks stop needing a file.

Note what is *not* in this table: a role no longer gets a deeper default merely because its subject matter sounds weighty. Reading code and forming a view costs the same whether the view is about security or about naming. Depth is bought by the function rules, per spawn, where it is load-bearing.

Anchor example: `${CLAUDE_PLUGIN_ROOT}/reference/worked-examples.md` Example 2 (Moderate-tier rate-limiting). The Phase-1 analysts spawn plainly and run on their frontmatter (advisory class at `high`, turn-capped); the Phase-2 lead is the Software Engineer, so it is already authoring class and needs no override; the Phase-3 adversarial reviewer is promoted to the authoring class by the reviewer-slot rule, regardless of which role fills it.

Second anchor (reviewer-slot wins regardless of role default): a Senior Technical Writer (role default: routine (`high`)) or a Senior Software Engineer (role default: implementation (`xhigh`)) spawned as the adversarial reviewer is a **reasoning** (`max`) spawn - the reviewer-slot rule wins over the role default. The slot takes that tier because of its function, not the reviewer's role.

#### Effort

Per-expert effort **is** controllable, via the `effort` field in each role's frontmatter, and the roles ship with it set (see Where Effort Actually Takes Effect above). Session effort covers the manager's own turns and is set once at triage; it is not raised mid-run.

An earlier version of this section said the opposite - that frontmatter was "a no-op for spawn configuration" because profiles reach experts only through the `SubagentStart` injection hook on `general-purpose` spawns. That was wrong on the platform as it now stands. The profiles in `${CLAUDE_PLUGIN_ROOT}/agents/` are registered as first-class subagent types (`oj:senior-*`) and are spawned by type, so their frontmatter is read: `model`, `effort`, `maxTurns`, `tools`, `disallowedTools`, and `skills` all take effect. Only `permissionMode`, `mcpServers`, and `hooks` are ignored for plugin-provided subagents. The injection hook remains as the fallback for `general-purpose` spawns, which is the only matcher it declares.

**Bound the advisory spawns.** Effort and model set the price per token; `maxTurns` bounds how many tokens there are. An unbounded advisory spawn does not stop at forming a view - it explores, and because a subagent re-reads its own growing transcript every turn, cost climbs steeply with turn count. In the reference sample the median expert ran 67 turns and the agents above 60 turns accounted for 80% of all delegation spend. Advisory roles therefore carry a `maxTurns` cap and are denied `Write`/`Edit`; the authoring role is left uncapped because its turns produce code.

One hard constraint: **do not disable thinking while effort is `xhigh` or `max`** - the API rejects that combination outright, which would break every Moderate and Complex engagement. Thinking is on by default, so this only bites an explicit opt-out.

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
