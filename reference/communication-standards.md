# Communication Standards

Technical communication standards, anti-patterns, and success metrics for OpenJunto engagements. Loaded for Complex tier where communication complexity justifies explicit standards; useful in Moderate tier when stakes are high.

> Communication is a separate quality axis from technical correctness. Correct work, badly communicated, is rejected work.

---

## 6 Communication Standards

### 1. Lead with Impact

Open every recommendation with what changes for the user or system. Not what was investigated, not what tools were used — what *changes*.

- **Bad**: "I reviewed the auth code and considered three approaches."
- **Good**: "Migrating to JWT cuts session-store cost by ~$8K/month and removes the cross-region replication bottleneck."

### 2. Quantify Everything

Numbers, not adjectives. If you cannot quantify, state explicitly that you cannot and explain why.

- **Bad**: "This will significantly improve performance."
- **Good**: "P99 drops from 420ms to ~180ms based on the synthetic benchmark in `artifacts/analysis/A-014.md`."
- **Acceptable**: "Cannot quantify pre-rollout; we will measure after the canary at 5% traffic."

### 3. Provide Runnable Examples

Code and config examples must be copy-pasteable. Pseudocode is a fallback, not a default. If the example needs adaptation, say so explicitly with the line(s) that vary.

### 4. Include Failure Scenarios

Every recommendation includes "and here is how this fails". Pre-mortem output belongs in the final deliverable, not buried in scratch notes.

### 5. Reference Actual Incidents

When invoking a past failure to justify a position, cite the incident by ID or date. "We have been burned by this before" without a reference is folklore.

### 6. Calculate TCO

Total cost of ownership, not first-day cost. Include: build, operate, maintain, retire. Most recommendations look cheap on day one; the operational tail is where decisions are won or lost.

---

## Standard Response Format

For Moderate and Complex deliverables, structure the final response in 7 sections.

```
RECOMMENDATION
[1–2 sentences: what to do, framed as a directive]

IMPACT
[What changes: user-facing, operational, financial. Quantified.]

IMPLEMENTATION
[Concrete steps, with file paths, commands, runnable examples.]

RISKS
[Pre-mortem output, top 2–3 failure scenarios.]

MITIGATION
[For each risk: specific action or accepted-risk justification.]

ROLLOUT
[Sequence, gates, rollback path. Canary if applicable.]

METRICS
[How we will know it worked: SLI, baseline, target, when measured.]
```

Simple-tier deliverables compress this to RECOMMENDATION + IMPACT + IMPLEMENTATION; the other sections are implicit in the perspective rotation.

---

## Anti-Patterns

| Anti-Pattern | Why Harmful | Instead |
|--------------|-------------|---------|
| **Unsubstantiated "no concerns"** | Reviewer fails the forcing function; coherent affirmation re-emerges. | State what was tested and why each test passed. |
| **Manufactured adversarial findings** | Inventing weak objections to satisfy the format poisons signal. | If you cannot find a strong objection, document the absence: "tested X, Y, Z; no material concerns; here is what would change my mind." |
| **Skipping triage** | The two-dimensional triage is what selects rigor. Skipping it produces wrong-tier work. | Every request starts with triage. Even "obvious" Simple tier work gets a one-line triage. |
| **Endless revision** | Three cycles without convergence indicates scope mismatch, not implementer error. | Trip the circuit breaker. Re-scope or escalate. |
| **Checkbox theater** | Going through Quality Gates without genuinely testing each item. | Each gate item gets a one-line justification, not just a check. |
| **Echo chamber** | Reviewer agrees with implementer because LLMs default to coherence. | Reviewer is a different profile, with adversarial framing in the prompt. |
| **Direct execution bypass** | Manager implements something "because it was faster" — peer review is destroyed. | If the spawn is broken, follow `failure-protocol.md`. Do not silently breach the delegation boundary. |
| **Premature workaround** | Patching a symptom because the root cause is hard. | Root cause goes in the deliverable as a follow-up item, even if the patch ships first. |
| **Struggling alone** | Manager spends 30+ minutes wrestling with a problem an expert could resolve in one spawn. | Time-box manager attempts. When stuck, delegate. |
| **Incomplete delegation** | Spawning an agent with vague task and no acceptance criteria. | Spawn prompt includes: role, task, scope, constraints, expected deliverable, success criteria. |

---

## Success Metrics

Targets for OpenJunto engagement quality. These are session-level indicators, not cross-session tracked.

| Metric | Target | Notes |
|--------|--------|-------|
| **First-response quality** | > 70% of deliverables accepted without revision | Measured at user acceptance. Revision rate above 30% suggests insufficient stakeholder analysis upfront. |
| **Triage accuracy** | > 85% of engagements stay in their triaged tier | Tier drift up = under-triaged; tier drift down = over-triaged. Both costly. |
| **Cycle time** | Simple < 30 min, Moderate < 2 hr, Complex < 8 hr | Exceeding these is a circuit-breaker signal. |
| **Peer review value** | > 40% of adversarial reviews surface a material finding | If reviewers consistently find nothing, the adversarial framing is failing — strengthen the prompt. |
| **Circuit breaker activations** | Monitor trend, not absolute | Increasing frequency = scope creep or triage drift. Decreasing = healthy. Zero over weeks = possibly under-triggering. |

### AI Agent Context Note

These metrics are session-level indicators. The Claude agent within a session can observe and report on them, but **cross-session tracking requires external tooling** — a backlog dashboard, a metrics store, or a manually maintained log. Out of the box, OpenJunto does not aggregate metrics across sessions; the agent has no persistent memory between sessions.

When the user asks "are we hitting these targets?", the honest answer is: "within this session, yes/no; across sessions, I do not have visibility — see `artifacts/status/` if it exists, or set up tracking."
