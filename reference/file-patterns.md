# File Patterns

Backlog management, project structure, and LLM-optimized file patterns for OpenJunto projects.

---

## Backlog Management

### Target Size

| Metric | Target | Action When Exceeded |
|--------|--------|----------------------|
| Total `.claude/BACKLOG.md` size | < 10 KB | Promote completed items to `backlog/detail/YYYY-QN.md`, keep index lean |
| Open items count | < 30 active | Triage: close, defer, or batch-close stale items |
| Single item description | < 200 words | Move detail into a referenced file under `artifacts/` |

### What Belongs Where

| Information | Location | Reason |
|-------------|----------|--------|
| Active work items, priorities, owners | `.claude/BACKLOG.md` | Volatile, frequently mutated, must be rewritable each session |
| Project conventions, design constraints, architectural decisions | `.claude/CLAUDE.md` | Stable, hand-edited, loaded into every session |
| Completed item history | `.claude/backlog/detail/YYYY-QN.md` | Archive — keeps BACKLOG.md lean while preserving the audit trail |
| Detailed analysis, ADRs, retrospectives | `.claude/artifacts/...` | Long-form documents referenced from BACKLOG.md or CLAUDE.md |
| Ephemeral session state | `.claude/state/session.md` | Carry-over between sessions; replaceable, not historical |

### Session Handoff Principles

1. **BACKLOG.md is the contract** — the next session reads BACKLOG.md to know what is in flight.
2. **CLAUDE.md is the constitution** — invariants the next session must honor.
3. **session.md is the diary** — what happened last time, decaying over weeks.
4. **artifacts/ are the receipts** — detailed evidence, referenced by ID.

When closing a session, the manager updates BACKLOG.md (item state) and session.md (carry-over) before clearing context. CLAUDE.md is hand-edited; never auto-rewritten.

---

## Standard Project `.claude/` Structure

### Minimum Viable (Day 1)

Brand-new projects start here. No premature scaffolding.

```
.claude/
  CLAUDE.md         # Project conventions, constraints, architectural decisions
  BACKLOG.md        # Active work items
```

That's it. Add structure when you feel the pain — not before.

### Full Structure (Mature Projects)

When the project has accumulated history, add:

```
.claude/
  CLAUDE.md
  BACKLOG.md
  state/
    session.md              # Volatile session carry-over
  artifacts/
    analysis/               # Investigations, evaluations, technical analyses
    program/                # ADRs, design docs, multi-quarter program plans
    meetings/               # Decision records from stakeholder/team discussions
    status/                 # Periodic status reports, retrospectives, KPI dumps
  archive/                  # Frozen artifacts kept for audit, not active reference
  backlog/
    detail/
      2026-Q1.md            # Closed items by quarter
      2026-Q2.md
```

### When to Promote from Minimum → Full

| Trigger | Action |
|---------|--------|
| BACKLOG.md exceeds 10 KB | Create `backlog/detail/` and start quarterly archives |
| First retrospective is written | Create `artifacts/status/` |
| First architectural decision needs persistence | Create `artifacts/program/` for ADRs |
| Multi-session work begins to recur | Create `state/session.md` |

---

## Persist Long-Running Context in CLAUDE.md

CLAUDE.md is the stable layer. Put things here when they are:

- **Design constraints** — e.g., "All API endpoints return JSON, never XML."
- **Architectural decisions** — e.g., "Service boundaries follow the bounded contexts in `artifacts/program/2026-Q1-bounded-contexts.md`."
- **Project-specific patterns** — e.g., "Background jobs use Sidekiq with a 5-minute retry budget."
- **Recurring trip wires** — e.g., "Do not touch `auth/legacy_session.rb`; it is being deprecated by `BL-203`."

Do NOT put here:

- Active work items (use BACKLOG.md).
- One-off task notes (use session.md).
- General programming knowledge already in the model (waste of tokens).

When CLAUDE.md grows past ~10 KB, audit for stale entries: items that were once trip wires but have since been resolved.

---

## Header/Detail Pattern

Used when a single file would grow past readability thresholds. Split into a thin index + detail files.

### Structure

```
artifacts/analysis/
  index.md                  # < 5 KB, table of contents
  detail/
    2026-Q1.md              # Full content for items closed in Q1
    2026-Q2.md
```

### Index Format

```markdown
# Analysis Index

| ID | Title | Date | Summary |
|----|-------|------|---------|
| A-001 | Cache eviction strategy | 2026-01-12 | LRU evaluated, ARC adopted. See [detail/2026-Q1.md#A-001](detail/2026-Q1.md#A-001). |
| A-002 | Auth token rotation cadence | 2026-02-03 | 90-day rotation, audit log mandatory. See [detail/2026-Q1.md#A-002](detail/2026-Q1.md#A-002). |
```

The index is what gets loaded into context for browsing. Detail files are read only when an entry is opened.

### Size Thresholds

| Size | Recommendation |
|------|----------------|
| < 10 KB | Single file is fine — do not split prematurely. |
| 10–25 KB | Consider splitting. Anchor: is the file being scrolled to find one section repeatedly? If yes, split. |
| > 25 KB | Must split. Beyond this size, the index/detail pattern becomes mandatory for context efficiency. |

### Use Cases

- **Completed backlog items**: `backlog/index.md` + `backlog/detail/YYYY-QN.md`.
- **Session retrospectives**: `artifacts/status/index.md` + `artifacts/status/detail/...`.
- **Artifact collections** (analyses, ADRs, meeting decisions): one index per collection, quarterly detail files.

> The point of the index is to be cheap to load. If your index file itself exceeds 5 KB, the index has become a detail file and needs its own index.
