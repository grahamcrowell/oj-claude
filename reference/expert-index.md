# OpenJunto Expert Agent Index

Central reference for the OpenJunto Expert Agent Coordination System. This index lists the roster of stakeholder perspectives, maps problem types to the experts who should weigh in, and documents the shared profile structure. The manager uses this file to select stakeholders during triage.

---

## 1. Overview

The OpenJunto coordination system is a roster of AI agent personas, each representing a senior stakeholder perspective. The manager identifies which perspectives a task requires, then engages them inline (Simple tier) or via the Task tool (Moderate/Complex tier). Every engagement includes a mandatory pair — Senior Distinguished Engineer + Senior Product Manager — plus any domain experts triggered by the work.

These agents are AI personas, not human consultants. They provide consistent, profile-driven guidance without persistent memory across sessions. Recommendations may require validation against actual organizational constraints, current tooling, or real-world data before they are adopted.

---

## 2. Quick Reference

### Mandatory Stakeholders (every tier)

| Stakeholder Perspective | File | Primary Purpose | Tie-Breaker Authority |
|---|---|---|---|
| Senior Distinguished Engineer | senior-distinguished-engineer.md | Technical strategy, architecture, risk | Technical decisions |
| Senior Product Manager | senior-product-manager.md | Business alignment, prioritization, scope | Business priorities |

### Domain Experts (engaged by trigger)

| Expert | File | Primary Purpose | Engagement Trigger |
|---|---|---|---|
| Senior Security Engineer | senior-security-engineer.md | Threat modeling, authn/authz, compliance | Security, auth, secrets, PII, compliance signals |
| Senior Data Architect | senior-data-architect.md | Schema, modeling, pipelines, lineage | Data modeling, ETL, warehouse, lineage signals |
| Senior Solutions Architect | senior-solutions-architect.md | Cross-system integration, boundaries | Multi-service or cross-system integration |
| Senior DevOps Engineer | senior-devops-engineer.md | CI/CD, infrastructure, deployment | Pipelines, infrastructure, release engineering |
| Senior Data Scientist | senior-data-scientist.md | Statistics, experimentation, inference | Experiments, statistical analysis, metrics |
| Senior ML Engineer | senior-ml-engineer.md | Model training, serving, evaluation | ML systems, model serving, training pipelines |
| Senior Enterprise Architect | senior-enterprise-architect.md | Portfolio strategy, standards, governance | Multi-system standards, portfolio-level decisions |
| Senior Business Analyst | senior-business-analyst.md | Requirements, process, stakeholder mapping | Requirements gathering, process redesign |
| Senior Technical Writer | senior-technical-writer.md | Documentation strategy, user-facing prose | Docs, user-facing guides, API references |
| Senior Engineering Consultant | senior-engineering-consultant.md | Independent third-party review | Outside perspective, neutral review |
| Senior Executive Leadership Coach | senior-executive-leadership-coach.md | Leadership, organizational dynamics | Org design, leadership coaching, executive comms |
| Senior Test Engineer | senior-test-engineer.md | Test strategy, quality engineering | Test plans, quality gates, coverage strategy |
| Senior Site Reliability Engineer | senior-sre.md | SLOs, reliability, operational toil | SLO design, reliability, on-call, capacity |
| Senior Software Engineer | senior-software-engineer.md | Implementation, code-level execution | Implementation execution after design |

---

## 3. Expert Selection Guide

Map the dominant problem type to its primary expert, then add the suggested supporting experts and a cross-cutting reviewer. **The cross-cutting reviewer is deliberately drawn from a different domain than the primary expert** — same-domain review tends toward coherent affirmation, while a peer from an adjacent domain surfaces blind spots (e.g., trust boundaries, operational toil, testability gaps).

| Problem Type | Primary Expert | Supporting Experts | Cross-Cutting Reviewer |
|---|---|---|---|
| Architecture decision | Senior Solutions Architect | Distinguished Engineer, DevOps | Senior Security Engineer |
| Security concern | Senior Security Engineer | Distinguished Engineer, SRE | Senior Solutions Architect |
| Data system design | Senior Data Architect | Distinguished Engineer, Data Scientist | Senior Security Engineer |
| ML system design | Senior ML Engineer | Data Architect, SRE | Senior Test Engineer |
| Reliability / SLOs | Senior Site Reliability Engineer | DevOps, Distinguished Engineer | Senior Product Manager |
| CI/CD or infrastructure | Senior DevOps Engineer | SRE, Distinguished Engineer | Senior Security Engineer |
| Experiment / statistics | Senior Data Scientist | Product Manager, Data Architect | Senior Distinguished Engineer |
| Product feature scope | Senior Product Manager | Distinguished Engineer, Business Analyst | Senior Test Engineer |
| Requirements / process | Senior Business Analyst | Product Manager, Technical Writer | Senior Distinguished Engineer |
| Test strategy | Senior Test Engineer | Distinguished Engineer, SRE | Senior Product Manager |
| Documentation strategy | Senior Technical Writer | Product Manager, Distinguished Engineer | Senior Business Analyst |
| Portfolio / standards | Senior Enterprise Architect | Solutions Architect, Distinguished Engineer | Senior Security Engineer |
| Org / leadership question | Senior Executive Leadership Coach | Product Manager, Business Analyst | Senior Distinguished Engineer |
| Implementation execution | Senior Software Engineer | Distinguished Engineer, Test Engineer | Senior Security Engineer |

**Tie-breaker authority** when the mandatory pair disagrees: technical deadlocks resolve to the Distinguished Engineer; business priority deadlocks resolve to the Product Manager. Mixed deadlocks escalate to the user with both positions documented.

---

## 4. Stakeholder Engagement by Execution Model

| Tier | How Stakeholders Engage | Profile Format | Output Format |
|---|---|---|---|
| **Simple** | Manager applies lenses inline (no sub-agent spawn) | Compact profiles (`${CLAUDE_PLUGIN_ROOT}/reference/compact/`) | PERSPECTIVE blocks (1 per stakeholder), then synthesis |
| **Moderate** | Stakeholders spawned via Task tool in parallel; implementer then adversarial reviewer | Full profiles (hook-injected) | 9-field handbacks (includes STRONGEST OBJECTION + FALSIFIER) |
| **Complex** | Coordinator + stakeholders run as a parallel team (swarm) | Full profiles (hook-injected) | 9-field handbacks, plus retrospective and steelmanned alternatives |

See `${CLAUDE_PLUGIN_ROOT}/reference/stakeholder-guide.md` for stakeholder identification by domain trigger and the escalation guard rules.

---

## 5. Profile Structure

Every full expert profile follows the same 16-section template. The structure is defined in detail in `${CLAUDE_PLUGIN_ROOT}/reference/expert-preamble.md` and is summarized here for reference.

1. Role Identity
2. Core Expertise
3. Key Responsibilities
4. Decision-Making Authority
5. Collaboration Style
6. Inter-Expert Collaboration
7. Tier-Specific Behavior
8. Quality Standards
9. Communication Patterns
10. Red Flags You Watch For
11. Limitations & Blind Spots
12. Key Questions You Ask
13. Common Patterns You Recommend
14. When NOT to Engage
15. Engagement Triggers
16. Success Indicators

---

## 6. Compact Profiles

Compact profiles live in `${CLAUDE_PLUGIN_ROOT}/reference/compact/` (one file per stakeholder, same basename as the full profile). They exist solely for the Simple tier inline perspective rotation, where the manager applies lenses directly without spawning sub-agents.

**Rationale — token optimization for Simple tier:**
- Roughly **80% size reduction** (~2KB vs. ~10KB for the full profile)
- Retains the essential adversarial elements (lens, red flags, key questions)
- Omits collaboration tables, detailed patterns, tier-specific behaviors, and other content that only matters when the expert is acting as a full sub-agent

**Compact profile structure** retains six elements:
1. Role identity (one line)
2. Lens — what this stakeholder examines
3. Red flags — top failure signals
4. Key questions — diagnostic prompts
5. Engagement triggers — when to apply this lens
6. When NOT to engage — fast-exit conditions

**When to use compact profiles:** Simple tier only, when the manager is producing inline PERSPECTIVE blocks.

**When NOT to use compact profiles:** Moderate or Complex tier. Sub-agents spawned via the Task tool receive the full profile via the `SubagentStart` hook (`oj-helper inject-profile`). Compact profiles lack the collaboration patterns and quality standards that full engagements require.

---

## 7. Maintenance

Update profiles in this index when:
- A new domain expert is added (update the Domain Experts table and Selection Guide)
- A profile filename changes (update both tables and any cross-references)
- A new problem type emerges that 2+ engagements have triaged consistently (add a row to the Selection Guide)

Do **not** update profiles for:
- One-off engagements that did not repeat
- Stakeholder preferences that already follow from the profile's existing guidance
- Style edits to the prose of an individual profile (those go in the profile file itself, not this index)

When adding a new stakeholder, ensure both a full profile (`${CLAUDE_PLUGIN_ROOT}/agents/<name>.md`) and a compact profile (`${CLAUDE_PLUGIN_ROOT}/reference/compact/<name>.md`) exist, and that the Expert Selection Guide places the new stakeholder as a primary expert for at least one problem type and as a cross-cutting reviewer for at least one other (to avoid same-domain echo chambers).
