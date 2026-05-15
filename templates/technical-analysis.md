# Technical Analysis: [TOPIC]

<!-- Use this template for investigations, evaluations, and technical deep dives. Copy to `.claude/artifacts/analysis/` and fill in each section. Delete bracketed placeholders as you go. -->

## Summary

[2-3 sentences: what was analyzed, key finding, recommendation. Lead with the bottom line — a reader who stops here should know what you concluded and what to do next.]

---

## Context

**Objective**: [What question are we answering? State it as a question.]

**Scope**: [What's included / excluded. Be explicit about the exclusions — they are usually where misunderstanding lives.]

**Constraints**: [Budget, timeline, technology, team, regulatory — whatever bounds the solution space.]

---

## Methodology

**Approach**: [How the analysis was conducted — e.g., benchmarks, code review, stakeholder interviews, literature survey.]

**Data Sources**: [Which systems, documents, or experts provided the information.]

**Assumptions**: [What we assumed to be true. Separate load-bearing assumptions — those that would invalidate the conclusion if wrong — from incidental ones.]

---

## Findings

<!-- One subheading per finding. Keep the four-field structure stable so readers can scan confidence without re-reading. -->

### Finding 1: [Title]

- **Observation**: [What was found.]
- **Evidence**: [Supporting data, pointer to measurement/code, or direct quotation.]
- **Confidence**: [High / Medium / Low — and one phrase on why.]
- **Implication**: [What this means for the decision.]

### Finding 2: [Title]

- **Observation**: [What was found.]
- **Evidence**: [Supporting data.]
- **Confidence**: [High / Medium / Low.]
- **Implication**: [What this means.]

<!-- Add additional findings as needed. A finding without evidence is an opinion. -->

---

## Options Analysis

<!-- Criteria as rows, options as columns. Use concrete values where possible (numbers, ratings, "yes/no") rather than prose. -->

| Criterion | Option A: [Name] | Option B: [Name] | Option C: [Name] |
|-----------|------------------|------------------|------------------|
| [Criterion 1 — e.g., Cost] | [Value] | [Value] | [Value] |
| [Criterion 2 — e.g., Time to ship] | [Value] | [Value] | [Value] |
| [Criterion 3 — e.g., Reversibility] | [Value] | [Value] | [Value] |
| [Criterion 4 — e.g., Risk profile] | [Value] | [Value] | [Value] |

---

## Recommendation

**Recommended Option**: [Option X] — [one-sentence rationale tying back to the objective.]

**Rationale**: [2-4 sentences. Why this option over the others. Reference the criteria above.]

**Next Steps**:

- [Action 1] — owner: [name/role], target: [date or milestone]
- [Action 2] — owner: [name/role], target: [date or milestone]
- [Action 3] — owner: [name/role], target: [date or milestone]

---

## Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| [Risk 1 — what could go wrong] | H/M/L | H/M/L | [Prevention or response plan] |
| [Risk 2] | H/M/L | H/M/L | [Plan] |
| [Risk 3] | H/M/L | H/M/L | [Plan] |

---

## Dissenting Views

<!-- Capture reviewer disagreements even if the recommendation stands. Future readers need to see the argument that was considered and rejected, not a sanitized consensus. -->

- **[Reviewer / role]**: [Summary of disagreement.] **Response**: [Why the recommendation still holds, or what would change if the dissent were accepted.]

---

## Metadata

- **Author**: [Expert role or name]
- **Reviewer**: [Expert role or name]
- **Date**: [YYYY-MM-DD]
- **Tier**: [Simple / Moderate / Complex]
