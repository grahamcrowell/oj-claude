# Stakeholder Guide

Stakeholder mapping, disagreement protocol, and steelman format. Use this file during triage (to identify required perspectives) and during conflict (to resolve disagreement structurally rather than improvisationally).

---

## Mandatory Pair

Every engagement, regardless of tier, includes:

- **Product Manager** (`senior-product-manager.md`) — represents user value, business priority, scope discipline.
- **Distinguished Engineer** (`senior-distinguished-engineer.md`) — represents architectural soundness, long-horizon cost, technical risk.

These two are the floor. Domain stakeholders below are added on top.

---

## Domain Signal → Stakeholder Mapping

Scan the task description for the signals in the left column. Add the corresponding stakeholder.

| Domain Signal | Stakeholder | Profile | Key Questions |
|---------------|-------------|---------|---------------|
| Security, auth, secrets, compliance, PII | Security Engineer | `senior-security-engineer.md` | What is the attack surface? Where is sensitive data? What is the blast radius of compromise? |
| Data modeling, pipelines, schema design | Data Architect | `senior-data-architect.md` | What is the source of truth? How does this evolve? What breaks at scale? |
| Cross-system integration, API contracts, distributed boundaries | Solutions Architect | `senior-solutions-architect.md` | What are the integration seams? Where are the failure boundaries? What gets versioned? |
| Infrastructure, CI/CD, deployment, environments | DevOps Engineer | `senior-devops-engineer.md` | How does this deploy? How is it rolled back? What is the observability surface? |
| Statistics, experimentation, metrics, analytics | Data Scientist | `senior-data-scientist.md` | What is being measured? How is the experiment powered? What is the inference target? |
| ML systems, model serving, training pipelines | ML Engineer | `senior-ml-engineer.md` | How is the model evaluated? How is drift detected? What is the retraining cadence? |
| Enterprise standards, governance, multi-team alignment | Enterprise Architect | `senior-enterprise-architect.md` | What standards apply? Who else owns adjacent systems? What is the long-term roadmap? |
| Requirements, business process, stakeholder elicitation | Business Analyst | `senior-business-analyst.md` | Who is the user? What is the as-is vs to-be? What is in scope? |
| Documentation, technical writing, API docs | Technical Writer | `senior-technical-writer.md` | Who is the reader? What is the task they are doing? What is the failure mode of misunderstanding? |
| Process improvement, ways-of-working, team dynamics | Engineering Consultant | `senior-engineering-consultant.md` | What is the root cause of friction? What is the smallest change with the largest leverage? |
| Leadership, executive comms, organizational change | Executive Leadership Coach | `senior-executive-leadership-coach.md` | Who is the audience? What decision needs to be made? What is the political terrain? |
| Test strategy, quality, coverage, regression | Test Engineer | `senior-test-engineer.md` | What is the test pyramid? Where do bugs escape? What is the cost of each test class? |
| SLOs, reliability, incident response, on-call | Site Reliability Engineer | `senior-site-reliability-engineer.md` | What are the SLIs/SLOs? What is the error budget? How is this paged on? |
| Code-level implementation, refactoring, idiomatic patterns | Software Engineer | `senior-software-engineer.md` | What is the readable shape? What is the test seam? What is the smallest correct change? |

### Stakeholder Escalation Guard

| Current Tier | Stakeholder Count | Action |
|--------------|-------------------|--------|
| Simple | 4 or more identified | Consider escalating to Moderate. Many perspectives needing deep analysis is itself a complexity signal. |
| Moderate | 5 or more identified | Consider escalating to Complex. Coordinator overhead becomes worthwhile. |

---

## Common Task Patterns

Quick lookup of recurring task types and the stakeholders they typically require (beyond the mandatory pair).

| Task Pattern | Additional Stakeholders |
|--------------|-------------------------|
| System architecture / new service design | Solutions Architect, Enterprise Architect, SRE |
| Security review / threat modeling | Security Engineer, SRE |
| Data pipeline / ETL design | Data Architect, DevOps Engineer |
| ML feature / model deployment | ML Engineer, Data Scientist, SRE |
| API design / public contract | Solutions Architect, Technical Writer, Security Engineer |
| Infrastructure migration | DevOps Engineer, SRE, Solutions Architect |
| Performance / scaling work | SRE, Solutions Architect, Software Engineer |
| Compliance / audit response | Security Engineer, Enterprise Architect, Technical Writer |
| Incident retrospective | SRE, Engineering Consultant |
| Test strategy overhaul | Test Engineer, Software Engineer, SRE |
| Documentation overhaul | Technical Writer, Business Analyst |
| Refactoring / code quality | Software Engineer, Test Engineer |

---

## Conflict Classification

When stakeholders disagree, classify the conflict before attempting resolution. Different conflict types route to different resolvers.

| Conflict Type | Primary Resolver | Escalation |
|---------------|------------------|------------|
| **Technical** — disagreement on implementation approach, language, pattern | Distinguished Engineer | Solutions Architect if cross-system, then user |
| **Business** — disagreement on scope, priority, user value | Product Manager | Business Analyst if requirements unclear, then user |
| **Mixed** — coupled technical/business trade-off (e.g., faster delivery vs cleaner abstraction) | DE + PM joint | User if joint deadlock persists |
| **Cross-Domain** — irreducible trade-off across domains (e.g., security latency cost vs UX target) | Stakeholders present trade-offs side-by-side | User decides — manager does not collapse the trade-off |

---

## Tension Classification

Not all disagreements should be resolved. Some are designed-in.

| Tension Type | Manager Action |
|--------------|----------------|
| **Resolvable** | Apply the primary resolver from the table above. Document the resolution. |
| **Trade-off** | Present options to user with explicit costs on each axis. User decides. |
| **Productive Tension** | **Forward as a design constraint** to the implementer and reviewer. Do NOT resolve. (Examples: security ↔ latency, cost ↔ reliability, velocity ↔ quality.) Both sides remain alive in the constraint set. |

> Resolving a productive tension produces a fake consensus that hides the real engineering work. The implementer's job is to live within the tension; the manager's job is to forward it intact.

---

## Resolution Steps

When a conflict requires resolution (not forwarding):

1. **Identify conflict type** using the table above. State the type out loud in the synthesis.
2. **Document positions** — capture each stakeholder's position and rationale verbatim.
3. **Apply resolver** — route the dispute to the primary resolver. The resolver produces a written decision.
4. **Time-box** — allow at most one round of rebuttal. Endless debate is a circuit breaker signal.
5. **Escalate** if deadlock persists. Present positions to the user with the resolver's recommendation.

### DISSENT Format

When a stakeholder is overruled but the position is substantive, record it:

```
DISSENT: [Stakeholder] | [Position + Rationale] | [Resolution: overruled by X because Y]
```

Dissent that gets recorded is dissent that can be revisited if reality later proves the dissenter right.

---

## Steelman Format

When rejecting alternatives, articulate the strongest version of the rejected position before rejecting it.

```
ALTERNATIVE: [Approach name]
STRONGEST ARGUMENT: [Best case for this approach, framed sympathetically — not a strawman]
WHY REJECTED: [Specific reason, with the alternative's strongest argument addressed]
```

### Steelman Requirements by Tier

| Tier | Steelman Requirement |
|------|----------------------|
| Simple | Note inline in synthesis if a notable alternative was considered |
| Moderate | One steelmanned alternative |
| Complex | 1–2 steelmanned alternatives, in the retrospective document |

---

## Example Conflicts

### Example 1: Caching Strategy

**Conflict**: Solutions Architect wants Redis; Software Engineer wants in-process LRU.
**Type**: Technical.
**Resolution path**: Distinguished Engineer evaluates trade-offs (operational complexity vs latency). DE picks in-process LRU; documents the SA position as DISSENT with the trigger condition for revisiting (latency p99 > 200ms).

### Example 2: Launch Date vs Test Coverage

**Conflict**: Product Manager wants Friday launch; Test Engineer wants two more days for regression suite.
**Type**: Mixed (business/technical).
**Resolution path**: DE + PM joint. Compromise: launch Friday behind feature flag at 5%, full rollout after regression completes. Both positions preserved.

### Example 3: Security Encryption vs Latency

**Conflict**: Security Engineer requires field-level encryption; SRE notes p99 latency budget cannot absorb the encryption cost.
**Type**: Cross-Domain. **This is a productive tension.**
**Resolution path**: Forward both constraints to the implementer as a design constraint. Implementer must find a path that respects both (e.g., async encryption, partial field encryption, scope reduction). Manager does NOT pick a winner.

### Example 4: Microservice vs Monolith

**Conflict**: Enterprise Architect wants microservice for strategic alignment; Distinguished Engineer wants monolith for current team size and operational maturity.
**Type**: Technical, with strategic overtones.
**Resolution path**: DE resolves with a documented decision: monolith now with explicit module boundaries that permit later extraction. EA's strategic concern recorded as DISSENT with the trigger condition (team grows past 12 engineers OR cross-cutting changes per week exceed 3).
