# Workflow Stages

Tactical execution detail for the three OpenJunto tiers: the workflow stages, the synthesis gate format, the pre-mortem gate, the adversarial review protocol, output compression, and the deputy coordinator pattern. Load on demand — Simple tier work rarely needs anything beyond the first table.

> The manager owns coordination. Experts own implementation. These stages exist so peer review is structurally guaranteed rather than situationally remembered.

---

## Workflow Stages by Tier

### Simple Tier (5 stages)

| Stage | Activity | Weight |
|-------|----------|--------|
| 1. Intake | Triage the request. Confirm Simple tier and the identified stakeholder set with the user. | Light |
| 2. Load Perspectives | Read compact profiles from `${CLAUDE_PLUGIN_ROOT}/reference/compact/<name>.md` for each identified stakeholder. | Light |
| 3. Perspective Rotation | Manager applies each stakeholder lens inline. Produce one PERSPECTIVE block per stakeholder. | Medium |
| 4. Synthesize + Execute | Merge perspectives into unified action. Delegate any code changes to a single implementer. | Medium |
| 5. Verify | Confirm output exists, looks correct, differs from baseline. Close Quality Gates (2 items). | Light |

> Simple tier is the explicit exception to the delegation boundary. Perspective rotation is the manager's job, but the PERSPECTIVE blocks are the forcing function — every identified stakeholder must produce one before action.

### Moderate Tier (7 stages)

| Stage | Activity | Weight |
|-------|----------|--------|
| 1. Intake | Triage. Confirm tier and stakeholders with the user. | Light |
| 2. Stakeholder Analysis | Spawn analysis agents in parallel via Task tool, one per stakeholder. Each produces a HANDBACK. | Heavy |
| 3. Synthesis Gate | Consolidate findings into a ledger (FINDING/TENSION). Classify constraints. Pause if any key assumption carries Low confidence. | Medium |
| 4. Pre-Mortem | Implementer-spawned agent enumerates ≥2 failure scenarios with mitigations or accepted risk. | Medium |
| 5. Implementation | Spawn a lead implementer with the synthesized ledger as input. Produce the work product. | Heavy |
| 6. Adversarial Review | Spawn a distinct reviewer agent. Find the single most important problem. Test failure modes. | Medium |
| 7. Deliver | Manager synthesizes into final response, closes Quality Gates (6 items), hands to user. | Light |

### Complex Tier (9 stages)

| Stage | Activity | Weight |
|-------|----------|--------|
| 1. Intake | Triage. Confirm Complex tier and the multi-stakeholder roster with the user. | Light |
| 2. Team Formation | `TeamCreate`. Spawn deputy coordinator + 3–5 stakeholder teammates (≤6 tasks each). | Medium |
| 3. Task Planning | Coordinator drafts the task graph: analysis tasks unblocked, implementation `blockedBy` analysis, review `blockedBy` implementation. | Medium |
| 4. Pre-Mortem | Coordinator-led, requires ≥3 scenarios spanning technical / operational / organizational / business categories. | Medium |
| 5. Parallel Execution | Teammates self-claim tasks. `plan_mode_required: true` for high-stakes implementation/review. | Heavy |
| 6. Adversarial Review | Independent reviewer teammate. Failure modes tested explicitly. Dissenting views recorded. | Heavy |
| 7. Synthesis | Coordinator compresses raw teammate output and relays a concise digest to the manager. | Medium |
| 8. User Checkpoint | Manager presents synthesis to user: **"Should we proceed?"** Cannot be skipped. | Light |
| 9. Retrospective | Coordinator or manager leads. Shutdown teammates structurally. `TeamDelete`. | Medium |

---

## Synthesis Gate

The synthesis gate sits between Stakeholder Analysis and Implementation in Moderate tier (and between analysis and implementation tasks in Complex tier). Its purpose is to convert raw analyst output into a structured ledger the implementer can act on.

### Findings Ledger Format

```
FINDING: [text]                                       | SOURCE: [role]            | CONFIDENCE: [H|M|L]
FINDING: [text]                                       | SOURCE: [role]            | CONFIDENCE: [H|M|L]
TENSION: [conflict description]                       | SOURCES: [role1, role2]   | STATUS: unresolved
```

- One FINDING per substantive analyst claim. Confidence is the analyst's own self-rated confidence.
- TENSION items capture irreducible disagreements between stakeholders. **TENSION items are PROTECTED** — they cannot be removed during synthesis and must be forwarded verbatim to the implementer and reviewer.
- If the ledger contains `CONFIDENCE: L` on any named key assumption, pause and present findings to the user before proceeding.

### Constraint Classification

After the ledger, classify each FINDING into one of three categories. The implementer is bound by Hard and Soft constraints differently.

| Class | Trigger | Implementer Obligation |
|-------|---------|------------------------|
| **Hard** | Backed by 2+ stakeholders OR raised by the domain authority for the relevant area | Must address. Cannot defer without manager + user approval. |
| **Soft** | Single stakeholder, non-authority context | Should address. May defer with explicit reasoning in the handback. |
| **Context** | Background information, not a binding requirement | Informs approach; no acceptance criterion. |

---

## Pre-Mortem Gate

Before any work product is produced, the implementer must answer:

> *"Imagine this shipped and failed. What went wrong?"*

### Requirements by Tier

| Tier | Minimum Scenarios | Coverage |
|------|-------------------|----------|
| Simple | Not required | — |
| Moderate | 2 | Any failure modes |
| Complex | 3 | Spanning ≥2 of: technical, operational, organizational, business |

### Output Format

```
PRE-MORTEM
SCENARIO 1: [Failure description]
  CAUSE: [Mechanism that produces the failure]
  MITIGATION: [Specific action] — or — ACCEPTED RISK: [Why we ship anyway]
SCENARIO 2: [...]
SCENARIO 3: [...]
```

Accepted risk is a legitimate outcome. The forcing function is naming the failure; not every failure must be engineered away.

---

## Adversarial Review Protocol

LLM agents default to coherent affirmation. The adversarial reviewer exists to break that default by structurally requiring critique.

### Reviewer Prompt

```
<!-- oj-expert: [reviewer-profile] -->
You are a [Reviewer Role].
**TASK**: Adversarial review of [deliverable]. Find the single most important correctness- or requirements-affecting problem.
Test these failure modes: [list, including any TENSION items from the synthesis gate].
Ignore stylistic and preferential concerns. If you find no material problem, explain specifically why this work is resistant to the failure modes you tested.
```

**Scope of review**: The reviewer flags ONLY gaps that affect **correctness** or **requirements** — behavior that is wrong, unsafe, or that fails to meet a stated requirement. Stylistic or preferential concerns (naming taste, formatting, alternative-but-equivalent approaches) are OUT of scope and must NOT be raised as review findings.

**"No material concerns" is an acceptable outcome at ALL tiers**: When the reviewer tests specific failure modes and finds no correctness- or requirements-affecting gap, the correct verdict is "None — resistant because [specific reasoning]", not a manufactured problem. This applies at Simple, Moderate, and Complex alike. It does NOT remove the obligation to run the review or to populate the FAILURE MODES TESTED section — the reviewer still runs and still documents what was probed.

### Reviewer Responsibilities

1. Test each named failure mode explicitly; report the result of each test. Confine findings to correctness- and requirements-affecting gaps; do not raise stylistic or preferential concerns.
2. Identify the **#1 problem** — the single most important material issue. Stack-ranked, not enumerated.
3. If no material concerns exist, **explain the absence**: what was tested, why each test passed. "No material concerns" is a valid, acceptable outcome at all tiers — bare "no concerns" without this specificity is rejected, but a specific, well-supported finding of no material concerns is complete and correct.

### Output Format

```
REVIEW: [Reviewer Role]
FAILURE MODES TESTED:
  - [Mode 1]: [Result — passed / failed / inconclusive] — [Evidence]
  - [Mode 2]: [Result] — [Evidence]
  - [...]
#1 PROBLEM FOUND: [Single most important issue, or "None — see absence rationale"]
ADDITIONAL CONCERNS: [Stack-ranked, optional]
CONFIDENCE CALIBRATION: [What would drop the implementer's confidence by one level]
VERDICT: [Accept | Accept with conditions | Reject]
```

---

## Output Compression

To keep the manager's context lean, compress expert output by role. The full handback may be 9 fields; the manager only needs what is decision-relevant.

| Role | Compression | What Survives |
|------|-------------|---------------|
| **Analyst** (Phase 1 / pre-implementation) | Compressed | FINDING / TENSION lines only. Drop rationale prose; reviewer can be re-spawned with full handback if needed. |
| **Implementer** | Standard | Full HANDBACK, but elide intermediate reasoning. Keep deliverable summary, pre-mortem, caveats. |
| **Reviewer** | Full | Verbatim. Adversarial output loses signal when summarized. |

Coordinators in Complex tier apply this compression before relaying to the manager.

---

## Deputy Coordinator Pattern

In Complex tier, a deputy coordinator agent operates between the manager and the stakeholder teammates. The coordinator is a general-purpose agent briefed with the full stakeholder plan.

### Coordinator Responsibilities

1. **Receives the full plan** from the manager (stakeholder roster, task graph, success criteria).
2. **Creates tasks** in the team via `TaskUpdate`, with `blockedBy` chains enforcing analysis → implementation → review ordering.
3. **Routes inter-stakeholder communication** — relays findings, escalates tensions, brokers plan approvals (`plan_approval_response`).
4. **Synthesizes raw teammate output** using the compression table above. Raw handbacks stay in the team scratchpad; the manager sees only the digest.
5. **Relays concise updates to the manager** at decision points (plan ready, blockers, user checkpoint due, retrospective complete).

The manager keeps the high-level decisions and user interaction; the coordinator absorbs the operational coordination. This pattern is what keeps Complex tier's manager context lean enough to make good decisions.

> Coordinator does NOT make high-level decisions or interact with the user directly. Escalations always route through the manager.
