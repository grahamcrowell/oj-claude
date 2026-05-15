# Why OpenJunto?

## The Problem

**Single-agent blind spots.** Out of the box, Claude jumps to implementation. It produces code that works on the happy path but systematically misses what a security engineer, an SRE, or a distinguished engineer would have flagged in ten seconds. Not because it *can't* reason about those things — because nothing in the default loop forces it to. LLMs optimize for internal consistency, not adversarial critique; left to defaults, they produce coherent-looking work that does not challenge its own assumptions.

**"Just prompt better" does not scale.** You cannot hold 16 expert perspectives in your head, remember which matter for this specific task, and rewrite the prompt every time. Even if you could, you'd still be the single reviewer — the same failure mode one level up.

**Context windows are the hard ceiling.** Stuffing every expert stance into one prompt dilutes the signal. The model averages across roles instead of committing to any of them. More instructions do not buy you more rigor; past a point, they buy you less.

**Result**: Code that works on the happy path but misses distributed bypass vectors, cache poisoning edge cases, thundering herds, and the operational burden nobody sized.

## How OpenJunto Works

A Manager agent triages every incoming request and selects the right domain experts. Domain experts analyze and build. A *different* expert reviews the work adversarially. Three tiers keep process weight proportional to risk:

- **Simple** — Manager rotates through stakeholder lenses inline; no sub-agents
- **Moderate** — parallel stakeholder analysis, lead implementation, adversarial review
- **Complex** — full coordinator-led team with retrospective

### Key Mechanics

- **16 domain experts** — Product Manager, Distinguished Engineer, Software Engineer, Security Engineer, DevOps Engineer, Site Reliability Engineer, Data Architect, Data Scientist, ML Engineer, Enterprise Architect, Solutions Architect, Business Analyst, Engineering Consultant, Executive Leadership Coach, Technical Writer, Test Engineer
- **Mandatory stakeholder perspectives** — Product + Tech on every request, plus domain experts signal-matched to the task
- **STRONGEST OBJECTION** — every handback must include the best counterargument to its own recommendation
- **FALSIFIER** — every recommendation names an empirical condition under which it would break in production
- **Pre-mortem gate** — before implementation on Moderate/Complex: *"Imagine this shipped and failed. What went wrong?"*
- **Circuit breaker** — auto-escalates to the user after 3 revision cycles or 2 hours without meaningful progress

## What This Actually Looks Like

Concrete example: *"Add rate limiting to the public API."*

**Without OpenJunto** — a working implementation: middleware, a counter, a per-user bucket, tests. Looks fine. Misses:

- **Distributed bypass** — attacker rotates IPs or user IDs to dodge per-key limits
- **Cache poisoning** — counter key is derived from a client-controlled header
- **Thundering herd** — synchronized window reset causes every rate-limited client to retry at the same millisecond
- **Storage cost at scale** — per-user counters in Redis with no eviction policy, unbounded growth
- **Degradation behavior** — backing store goes down; does the limiter fail open, fail closed, or crash?
- **Observability** — no metrics on limit hit rate, so you cannot tune the threshold or spot abuse

**With OpenJunto** — Manager triages as **Moderate** (multi-domain + production stability risk). Selects Security + DevOps + Software Engineer + Distinguished Engineer. Security flags bypass vectors and cache-key injection. DevOps sizes storage and specifies degradation behavior. Software Engineer implements with findings incorporated. Distinguished Engineer adversarially reviews — tests failure modes, checks observability, probes High-confidence claims. Manager synthesizes, surfaces any dissent, hands back.

The code still ships. It's just the code you would have ended up with after the first incident, not before.

## Honest Tradeoffs

| Tradeoff | Reality |
|----------|---------|
| **Token cost** | 2–5× more tokens than baseline Claude — parallel expert spawns, handback structure, reference loads |
| **Wall-clock time** | Moderate tasks take minutes, not seconds; Complex can take longer |
| **Learning curve** | ~1 week to internalize the triage model, handback format, and when to push back |
| **Process discipline** | You must answer triage questions, approve stakeholder selection, read structured handbacks |
| **Over-processing risk** | Simple tasks can get over-triaged if you don't push back — "this is a typo fix, just do it" |
| **Verbosity** | Expert handbacks are explicit and structured — more text to read, less ambiguity |

### When OpenJunto is NOT Worth It

- Quick one-off questions (`what does this flag do?`)
- Trivial fixes — typos, import ordering, whitespace
- Rapid prototyping where you're throwing the code away tomorrow
- Tasks where you already know exactly what you want and just need keystrokes

### When OpenJunto IS Worth It

- Security reviews
- Architectural decisions with multi-month consequences
- Cross-system changes
- Compliance-sensitive work (PCI, HIPAA, SOC2)
- Production incident response
- Anything where "looks good to me" is not good enough

OpenJunto is slower. It is also the thing that catches what would have cost you a week of incident response.

## Try It

Install (see [README](README.md)), then point it at something real:

> `Review this pull request for security issues and operational readiness.`

Run the same prompt through single-agent Claude and through OpenJunto. Compare the output. The difference is the point.
