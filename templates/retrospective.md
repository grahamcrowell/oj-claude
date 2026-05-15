# Retrospective: [Engagement Title]

> **Date**: [YYYY-MM-DD]
> **Engagement Tier**: [Complex | Moderate]
> **Participants**: [Experts involved]
> **Facilitator**: Senior Technical Project Manager

<!-- Use this template for Complex tier retrospectives (required) and optionally for Moderate tier engagements when significant issues arose. Target completion time: 15 minutes. -->

---

## Engagement Summary

- **Original Request**: [What the user asked for, in their words where possible]
- **Delivered Outcome**: [What was actually delivered — name the artifact or result]
- **Duration**: [Time from start to completion]
- **Experts Engaged**: [List of experts who participated]
- **Tier Classification**: [Complex | Moderate]
- **Circuit Breaker Activated**: [Yes / No — if yes, explain which trigger and how it was resolved]

---

## What Went Well

<!-- Practices, decisions, or patterns that contributed to success. Name them concretely so they can be repeated. -->

| # | Item | Impact |
|---|------|--------|
| 1 | [Positive observation] | [How it helped] |
| 2 | [Positive observation] | [How it helped] |
| 3 | [Positive observation] | [How it helped] |

### Details

[Elaborate on the key positives worth reinforcing — one short paragraph. Focus on what made them work, not just that they worked.]

---

## What Could Be Improved

<!-- Challenges, friction points, or suboptimal patterns observed. Root Cause is required — "ran out of time" is a symptom, not a cause. -->

| # | Item | Impact | Root Cause |
|---|------|--------|------------|
| 1 | [Improvement area] | [How it hindered] | [Why it happened] |
| 2 | [Improvement area] | [How it hindered] | [Why it happened] |
| 3 | [Improvement area] | [How it hindered] | [Why it happened] |

### Details

[Elaborate on the key improvements needed — one short paragraph. Tie each to the root cause and name the specific change that would prevent recurrence.]

---

## Questions & Puzzles

<!-- Unresolved observations that need further thought. Not action items — these are things you don't yet know how to act on. -->

- [Question or observation that remains unclear]
- [Pattern noticed that warrants further investigation]
- [Apparent contradiction or surprising result]

---

## Action Items

<!-- Concrete changes to make based on learnings. Every action needs an owner and a target. -->

| # | Action | Owner | Target | Priority |
|---|--------|-------|--------|----------|
| 1 | [Specific action] | [Who] | [When] | [H/M/L] |
| 2 | [Specific action] | [Who] | [When] | [H/M/L] |
| 3 | [Specific action] | [Who] | [When] | [H/M/L] |

### Action Categories

- **Process**: Changes to workflow or procedures
- **Profile**: Updates to expert profiles
- **Template**: Changes to templates
- **Documentation**: Updates to CLAUDE.md or index.md

---

## Metrics Review

<!-- Session-level indicators, not tracked across sessions. AI agents cannot measure cross-session trends without external tooling. -->

| Metric | This Engagement | Notes |
|--------|-----------------|-------|
| Rework cycles | [0-N] | [Context — what triggered each] |
| Expert deadlocks | [0-N] | [How resolved] |
| Tier classification accuracy | [Correct / Changed] | [If changed, why] |
| Quality gates passed | [X / Y] | [Any skipped? Why?] |
| User checkpoints | [Count] | [Feedback received] |

---

## Profile/Process Updates Identified

<!-- Specific, actionable updates. "Profile should be clearer" is not actionable; "Add a pre-flight checklist to section 3" is. -->

### Profile Updates

| Profile | Section | Proposed Change |
|---------|---------|-----------------|
| [Expert] | [Section] | [What to change] |

### Process Updates

| Document | Section | Proposed Change |
|----------|---------|-----------------|
| CLAUDE.md | [Section] | [What to change] |
| [Reference file] | [Section] | [What to change] |

---

## Quality Checklist

Before finalizing, verify:

- [ ] Engagement summary is accurate and complete
- [ ] Both positives AND improvements are documented
- [ ] Action items are specific and have owners
- [ ] Profile/process updates are captured for future implementation
- [ ] Metrics provide useful signal about engagement quality

---

## Usage Notes

### When to Use

- **Required**: After every Complex tier engagement.
- **Optional**: After Moderate tier engagements when significant issues arose.

### Time Target

- Complete within 15 minutes per CLAUDE.md workflow. A retrospective that takes longer usually means the engagement itself is still open.

### Follow-Through

- Action items should be tracked in BACKLOG.md or the configured issue tracker.
- Profile updates should be implemented in subsequent sessions.
- Process updates should be proposed to the user for approval before being written to CLAUDE.md or reference files.

### AI Agent Context

As AI agents with no persistent memory between sessions, we cannot:

- Track action items across sessions without external tooling
- Measure trends over time
- Remember learnings from previous retrospectives

Therefore, retrospectives primarily serve to:

1. Document learnings for the user
2. Identify immediate improvements
3. Propose profile/process updates for this session
