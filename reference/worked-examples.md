# Worked Examples

End-to-end worked examples across the three OpenJunto tiers, demonstrating triage → execution → verification. Each example shows the exact prompts, formats, and decision points that a real engagement would produce.

---

## Example 1: Simple Tier — Health Check Endpoint

### User Request

> "Add a `/health` endpoint to the API service that returns 200 OK with the build SHA."

### Triage

**Execution model criteria scored**: 0/4
- [ ] Spans multiple technical domains? No — single service, single language.
- [ ] Regulatory or compliance implications? No.
- [ ] Could impact production stability? No — additive, idempotent.
- [ ] Significant cost or resource commitment? No.

**Tier**: Simple.

**Stakeholders identified**:
- Product Manager (mandatory)
- Distinguished Engineer (mandatory)
- Software Engineer (signal: code-level implementation)

**Confirmation to user**:
> "I've triaged this as Simple with 3 stakeholders: Product Manager, Distinguished Engineer, Software Engineer. Proceeding with inline perspective rotation."

### Inline Perspective Rotation

```
PERSPECTIVE: Product Manager (senior-product-manager.md)
LENS: User value, scope discipline, lifecycle cost.
ASSESSMENT: Useful for load balancer probes and oncall debugging. Scope is small and well-defined.
CONCERN: None — endpoint is a primitive, not a feature. Watch for scope creep into "dashboard for health" later.
```

```
PERSPECTIVE: Distinguished Engineer (senior-distinguished-engineer.md)
LENS: Architectural soundness, long-horizon cost.
ASSESSMENT: Standard pattern. Return JSON with `status: "ok"` and `sha: <build_sha>`. No auth on this path; expose only the build SHA, not commit messages or dependency versions.
CONCERN: Endpoint must not exercise downstream dependencies (database, cache). It is liveness, not readiness — keep them separate.
```

```
PERSPECTIVE: Software Engineer (senior-software-engineer.md)
LENS: Readable shape, test seam, smallest correct change.
ASSESSMENT: One handler in the existing router; build SHA injected at compile time via existing ldflags pattern. One unit test asserting 200 + JSON shape.
CONCERN: Don't introduce a new package for this. Add to the existing handlers package.
```

### Synthesis

> Add `GET /health` to the existing handlers package. Return `{"status": "ok", "sha": "<build_sha>"}` with HTTP 200. No downstream calls. Build SHA via existing ldflags. One unit test for shape and status. Note: this is liveness only — readiness is a separate endpoint if needed later.

Delegated to a Software Engineer agent for implementation.

### Verification Checklist

- [ ] Endpoint file exists in `handlers/` package
- [ ] Test file exists with shape + status assertion
- [ ] Build SHA appears in response when binary is built with the standard ldflags
- [ ] Endpoint does NOT touch the database or cache
- [ ] All 3 PERSPECTIVE blocks documented above
- [ ] Quality Gates (Simple, 2 items) closed

---

## Example 2: Moderate Tier — Rate Limiting for Public API

### User Request

> "Add rate limiting to our public API. It's getting abused — we're seeing 50× normal traffic from a handful of IPs."

### Triage

**Execution model criteria scored**: 2/4
- [x] Spans multiple technical domains? Yes — API code, infra (CDN/edge), observability.
- [ ] Regulatory or compliance implications? No.
- [x] Could impact production stability? Yes — bad config blocks legitimate users.
- [ ] Significant cost or resource commitment? No.

**Tier**: Moderate.

**Stakeholders identified**:
- Product Manager (mandatory)
- Distinguished Engineer (mandatory)
- Security Engineer (signal: abuse, attack surface)
- DevOps Engineer (signal: infra, edge config)

### Phase 1: Parallel Stakeholder Analysis

**Security spawn prompt** (Task tool, model: sonnet):

```
<!-- oj-expert: senior-security-engineer -->
You are a Senior Security Engineer.
**TASK**: Analyze the abuse pattern (50× normal traffic from few IPs) and recommend a rate-limiting
strategy from a security perspective. Cover: per-IP limits vs per-token, sliding-window vs token-bucket,
behavior on limit (429 vs silent drop vs tarpit), and how to avoid blocking legitimate users behind
shared NAT. Do NOT implement — analysis only.
```

**DevOps spawn prompt** (Task tool, model: sonnet):

```
<!-- oj-expert: senior-devops-engineer -->
You are a Senior DevOps Engineer.
**TASK**: Analyze where rate limiting should live in our stack: at the CDN edge, at the API gateway,
or in application code. Cover trade-offs: latency cost, observability, rollback path, multi-region
consistency. Do NOT implement — analysis only.
```

These run in parallel.

### Synthesis Gate

Findings ledger:

```
FINDING: Per-IP rate limiting will block shared-NAT users. Token-based limits preferred for
  authenticated endpoints; IP-based only for unauthenticated.   | SOURCE: Security    | CONFIDENCE: H
FINDING: Token-bucket with burst capacity = 2× steady-state matches our traffic pattern
  (interactive bursts followed by quiet periods).                | SOURCE: Security    | CONFIDENCE: M
FINDING: Edge-tier rate limiting (CDN) costs nothing but is coarse-grained and slow to update.
  API-gateway tier is the sweet spot.                            | SOURCE: DevOps      | CONFIDENCE: H
FINDING: Rate-limit responses must include Retry-After and a structured error body so SDKs
  back off correctly.                                            | SOURCE: Security    | CONFIDENCE: H
TENSION: Security wants strict default limits; DevOps notes that strict limits without
  observability will look identical to an outage.                | SOURCES: Security, DevOps | STATUS: unresolved
```

Constraint classification:
- **Hard**: Token-based for authenticated paths (Security domain authority). Response includes Retry-After (cross-stakeholder agreement).
- **Hard**: Rate-limit decisions emit a metric per (endpoint, outcome) — addresses the TENSION.
- **Soft**: API-gateway tier preferred (single stakeholder, DevOps).
- **Context**: 50× traffic is the abuse pattern that motivated the work.

The TENSION is forwarded to the implementer as a design constraint, not resolved.

### Phase 2: Lead Implementation

**Implementer spawn prompt** (Task tool, model: sonnet):

```
<!-- oj-expert: senior-software-engineer -->
You are a Senior Software Engineer.
**TASK**: Implement rate limiting for our public API based on the synthesized stakeholder findings.

Hard constraints:
- Token-based limits on authenticated endpoints; IP-based on unauthenticated paths.
- Token-bucket algorithm, burst = 2× steady-state.
- 429 response with Retry-After header and structured JSON error body.
- Emit Prometheus metric `rate_limit_decisions_total{endpoint, outcome}` on every decision.

Soft constraint:
- Prefer API-gateway tier (Envoy/Kong) over application code; fall back to application code if
  gateway-tier instrumentation is insufficient.

Design tension forwarded (do NOT resolve unilaterally): Security wants strict defaults; DevOps
warns strict + unobservable = looks like an outage. Your implementation must make rate-limit
events visible enough that oncall can distinguish them from a real outage.

Complete a pre-mortem (≥2 failure scenarios) before producing the work product.
```

### Phase 3: Adversarial Review

**Reviewer spawn prompt** (Task tool, model: opus):

```
<!-- oj-expert: senior-security-engineer -->
You are a Senior Security Engineer.
**TASK**: Adversarial review of the rate-limiting implementation. Find the single most important problem.

Test these failure modes explicitly:
- Token-based limit on authenticated endpoints leaks information about token validity (timing,
  response-shape differences).
- Burst behavior allows an attacker to amortize attacks across burst windows.
- Distributed rate-limit state has a race condition under high concurrency.
- 429 + Retry-After honored by SDKs but ignored by abusive clients — what is the fallback?
- The forwarded TENSION (strict + observable): does the metric cardinality blow up Prometheus?

Stack-rank your findings. Identify the #1 problem.
```

---

## Example 3: Complex Tier — Authentication Migration (Sessions → JWT)

### User Request

> "We need to migrate from server-side sessions to JWT-based authentication. We have 2M active users, regulatory requirements on session revocation, and a mobile + web client surface."

### Triage

**Execution model criteria scored**: 5 (mandatory escalation triggered)
- [x] Spans multiple technical domains? Yes — auth backend, mobile, web, infra.
- [x] Regulatory or compliance implications? Yes — session revocation requirement.
- [x] Could impact production stability? Yes — 2M users, auth is critical path.
- [x] Significant cost or resource commitment? Yes — multi-quarter effort.
- [x] **Mandatory escalation**: Security architecture change, regulatory implications.

**Tier**: Complex.

**Stakeholders identified** (7):
- Product Manager (mandatory)
- Distinguished Engineer (mandatory)
- Security Engineer (auth architecture)
- Solutions Architect (cross-system integration: backend + mobile + web)
- DevOps Engineer (rollout, rollback)
- SRE (auth SLOs, observability)
- Test Engineer (regression risk on critical path)

### Team Formation

```
Manager
  └─ Coordinator (deputy, general-purpose agent, full plan in context)
       ├─ Security Engineer teammate    (analysis → review)
       ├─ Solutions Architect teammate  (analysis → implementation seam)
       ├─ Distinguished Engineer        (lead implementer)
       ├─ DevOps Engineer teammate      (analysis → rollout)
       ├─ SRE teammate                  (analysis → adversarial review)
       └─ Test Engineer teammate        (analysis → adversarial review)
```

`TeamCreate` invoked with `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`.

### 8-Step Execution Flow

1. **Manager → Coordinator**: hands over the full plan (stakeholder roster, success criteria, regulatory constraints).
2. **Coordinator → Teammates**: creates analysis tasks (T1–T6), all unblocked, parallel.
3. **Teammates self-claim**: each picks the lowest available ID via `TaskUpdate`.
4. **Coordinator runs synthesis gate**: collects analyst output, builds the ledger, classifies constraints, surfaces TENSION items.
5. **Coordinator creates implementation task** (T7) with `blockedBy: [T1, T2, T3, T4, T5, T6]`. `plan_mode_required: true`. DE claims it, drafts plan, coordinator approves via `plan_approval_response`.
6. **Coordinator creates review task** (T8) with `blockedBy: [T7]`. `plan_mode_required: true`. SRE + Test Engineer co-review (adversarial). Dissents recorded.
7. **Coordinator synthesizes** the implementation + review into a digest. Compression rules applied (analysts compressed, implementer standard, reviewer verbatim).
8. **Coordinator → Manager**: delivers digest. Manager runs **User Checkpoint** — presents synthesis to user with explicit question **"Should we proceed?"** Retrospective only begins after user approval.

### Task Graph (declarative dependencies)

```
T1  analysis-security        (Security)        blockedBy: []
T2  analysis-solutions       (Solutions Arch)  blockedBy: []
T3  analysis-devops          (DevOps)          blockedBy: []
T4  analysis-sre             (SRE)             blockedBy: []
T5  analysis-test            (Test)            blockedBy: []
T6  analysis-product         (PM lens)         blockedBy: []
T7  implementation           (DE, plan_mode)   blockedBy: [T1,T2,T3,T4,T5,T6]
T8  adversarial-review       (SRE+Test,        blockedBy: [T7]
                              plan_mode)
T9  retrospective            (Coordinator)     blockedBy: [T8]  — after user checkpoint
```

After T9, the coordinator issues `shutdown_request` to each teammate, awaits `shutdown_response`, then the manager invokes `TeamDelete`. Dissents and rejected alternatives are preserved in the retrospective document.
