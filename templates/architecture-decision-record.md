# ADR-[NUMBER]: [TITLE]

<!-- Use this template for significant technical decisions requiring documentation. File under `.claude/artifacts/analysis/adr-NNNN-slug.md` or a project-specific ADR directory. Each ADR is written once and only amended via Status changes or a superseding ADR. -->

## Status

[Proposed | Accepted | Deprecated | Superseded by ADR-XXX]

## Date

[YYYY-MM-DD]

---

## Context

[What situation or problem motivates this decision? Include the forces at play: technical constraints, organizational pressures, deadlines, prior decisions that brought us here. A reader new to the project should understand why this decision is being made now.]

---

## Decision Drivers

<!-- The factors that, if weighed differently, would change the outcome. Keep to what actually influences the choice — not generic virtues. -->

- [Driver 1 — e.g., "Must support 10x traffic growth within 12 months"]
- [Driver 2 — e.g., "Team has no Kubernetes experience"]
- [Driver 3 — e.g., "Data residency required in EU"]
- [Driver 4]

---

## Considered Options

<!-- Document at least three alternatives. Two options is often a false binary; three forces genuine trade-off analysis. -->

### Option A: [Name]

[Brief description — what it is, how it works at a high level.]

### Option B: [Name]

[Brief description.]

### Option C: [Name]

[Brief description.]

---

## Decision

We will implement **[Option X]** because [concise rationale grounded in the decision drivers].

[2-4 sentences elaborating the reasoning. Reference the drivers explicitly — readers should see the chain from driver → chosen option.]

---

## Reversibility Assessment

> **This section is critical for one-way doors.** Decisions that are hard to reverse deserve proportionally more scrutiny up front. If "One-way door?" is Yes, a pre-mortem and explicit user approval are required before Accepted status.

**Reversibility**: [Easy / Moderate / Difficult / Irreversible]

**Reversal cost if wrong**: [What would it take to undo? Engineering weeks, data migration, customer notification, contractual changes? Quantify where possible.]

**One-way door?**: [Yes / No]

<!-- If Yes, add a paragraph here describing the additional scrutiny applied: pre-mortem scenarios, dissenting reviews considered, stakeholders explicitly signed off. -->

---

## Consequences

### Positive

- [Benefit 1 — what becomes possible or cheaper]
- [Benefit 2]
- [Benefit 3]

### Negative

- [Tradeoff 1 — what becomes harder, more expensive, or foreclosed]
- [Tradeoff 2]
- [Tradeoff 3]

### Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| [Risk 1 — a specific scenario, not a generic concern] | H/M/L | H/M/L | [Plan that actually reduces likelihood or impact] |
| [Risk 2] | H/M/L | H/M/L | [Plan] |

---

## Validation

[How will we know this decision was correct? Define observable signals, not feelings.]

- [Success metric 1 — measurable outcome and target]
- [Success metric 2]
- [Failure signal — what would tell us we got it wrong]

**Review Date**: [When should this decision be revisited? Tie to a milestone or date, not "eventually".]

---

## References

- [Related ADRs: ADR-NNNN]
- [Design documents, RFCs, external articles]
- [Incidents or prior work that informed this decision]

---

## Metadata

- **Author**: [Expert role or name]
- **Reviewers**: [List — one reviewer is not review]
- **Approved by**: [Manager / User — required for Accepted status]
