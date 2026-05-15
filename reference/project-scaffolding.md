# Project Scaffolding

Opt-in infrastructure for mature OpenJunto projects: session state, carry-over compression, context maps, artifact organization, snapshot caching, communications playbook, and the session lifecycle. New projects start with minimum viable structure (see `file-patterns.md`); these patterns are adopted when pain points emerge.

---

## Session State Separation

Two layers, deliberately different lifecycles.

| Layer | File | Lifecycle | What Goes Here |
|-------|------|-----------|----------------|
| **Stable** | `.claude/CLAUDE.md` | Hand-edited, rarely changes | Project constraints, architectural decisions, recurring trip wires, conventions |
| **Volatile** | `.claude/state/session.md` | Rewritten each session, decays over weeks | Carry-over from last session, in-flight context, recent decisions not yet promoted |

The manager NEVER writes to CLAUDE.md mid-session. It writes to session.md at session close. Promotion from session.md → CLAUDE.md is a human decision: "this carry-over kept appearing for 3 sessions; it belongs in the stable layer."

---

## Carry-Over Compression

`state/session.md` accumulates context across sessions but must not bloat indefinitely. Apply an aging policy on each session save.

| Age | Action |
|-----|--------|
| Current session + last 2 sessions | Keep full text |
| 7–14 days old | Compress to one-line bullet ("[date]: [decision/event]") |
| 14+ days old | Remove unless promoted to CLAUDE.md or an artifact file |

Session save discipline: when collapsing entries, preserve the date and the actor (manager / specific expert). Compressed lines remain searchable.

> Items that survive compression three times are candidates for CLAUDE.md promotion — they have proven they belong in the stable layer.

---

## Context Map (`llms.txt`)

For projects with 10+ files under `.claude/`, add a context map at `.claude/llms.txt` so future sessions know what to load first. The format borrows from `llms.txt` for websites: a flat, machine-readable index.

### Format

```markdown
# Project Context Map

## Core Files
| File | Purpose |
|------|---------|
| CLAUDE.md | Project constraints and architectural decisions |
| BACKLOG.md | Active work items |
| state/session.md | Session carry-over |

## Reference
| File | When to Load |
|------|--------------|
| artifacts/program/2026-Q1-bounded-contexts.md | Service boundary decisions |
| artifacts/analysis/index.md | Past investigations index |
| artifacts/status/index.md | Retrospectives and status reports |

## Loading Guide
- Start with: CLAUDE.md, BACKLOG.md, state/session.md
- On architectural work: read artifacts/program/*
- On debugging: search artifacts/analysis/* first
```

The file is not auto-loaded. The manager reads it explicitly when orienting in an unfamiliar project.

---

## Artifact Organization

Four subdirectories under `.claude/artifacts/`, each with a distinct lifecycle.

| Subdirectory | Purpose | Lifecycle |
|--------------|---------|-----------|
| `analysis/` | Investigations, evaluations, technical deep-dives | Created once; referenced often; rarely edited after creation |
| `program/` | ADRs, multi-quarter design docs, program-level plans | Living documents; revised when decisions change; never deleted |
| `meetings/` | Decision records from stakeholder discussions, user checkpoints | Append-only; dated; preserved for audit |
| `status/` | Periodic status reports, retrospectives, KPI snapshots | Append-only; rolled into index/detail pattern after 10+ entries |

When in doubt, default to `analysis/`. Promote to `program/` only when a decision has become structural (binding future work).

---

## Snapshot Caching Contract

Some commands produce expensive-to-generate data (e.g., dependency graphs, codebase audits). Cache these snapshots with a 2-hour TTL by convention.

```bash
SNAPSHOT_DIR=".claude/state/snapshots"
SNAPSHOT_FILE="$SNAPSHOT_DIR/dependency-graph.json"
TTL_SECONDS=7200

mkdir -p "$SNAPSHOT_DIR"

if [ -f "$SNAPSHOT_FILE" ] && [ $(($(date +%s) - $(stat -f %m "$SNAPSHOT_FILE" 2>/dev/null || stat -c %Y "$SNAPSHOT_FILE"))) -lt $TTL_SECONDS ]; then
  cat "$SNAPSHOT_FILE"
else
  generate_dependency_graph > "$SNAPSHOT_FILE"
  cat "$SNAPSHOT_FILE"
fi
```

Conventions:

- Snapshots live under `.claude/state/snapshots/`.
- Filename includes the source command for traceability.
- Stale snapshots (>2h) are regenerated, not served. There is no "use stale on failure" fallback unless the user opts in.
- Snapshots are local-only; they do not get committed.

---

## Communications Playbook

For projects that span teams, communication fatigue becomes a real cost. `.claude/COMMS.md` captures the playbook.

### Signal Gate — When to Communicate

Before posting anything outward, the manager asks:

1. Has something changed since the last update? (No change → no post.)
2. Does the audience need to act on this? (No action → maybe skip.)
3. Is this the right channel? (Wrong channel → reroute, do not double-post.)

If all three are yes, communicate. Otherwise, hold.

### Hierarchy Rule — One Event = One Post

A single event produces exactly one outbound communication, in the highest-level channel that captures the audience. Do not multi-channel-post the same event.

Examples:
- Deploy completes → one Slack post in `#release-channel`. Do not also email, do not also Jira-comment.
- Incident resolved → one post in `#incidents`. Engineering-wide channels reference the incident channel, do not duplicate.

### Channel Routing Table

| Event Class | Primary Channel | When Escalated |
|-------------|-----------------|----------------|
| Release / deploy | `#release-{component}` | Email to leadership on Sev-1 |
| Incident / outage | `#incidents` | Page oncall, then exec on Sev-1 |
| Decision (architectural, scope) | `artifacts/meetings/YYYY-MM-DD.md` + Slack thread link | Stakeholder DMs if dissenting view |
| Status / weekly | `#status-{team}` | Roll up to monthly leadership email |
| Question for stakeholder | DM or threaded reply | Channel post only after DM unanswered 24h |

### Drafts Queue

`.claude/state/comms-drafts.md` holds outbound messages awaiting send. Each entry includes channel, audience, draft text, and a send-by date. Manager batches sends rather than firing piecemeal.

### Log

`.claude/state/comms-log.md` records what was sent and when. Append-only. Useful for retrospectives and for the signal-gate check ("has something changed since the last update?").

---

## Session Lifecycle

Every session follows a three-phase pattern. The phases are reusable building blocks; not every session triggers all three.

### Health Check (Pre-Session Validation)

Before beginning real work, run 5 checks:

1. **Backlog freshness** — is BACKLOG.md non-empty and current (last-modified < 7 days)?
2. **CLAUDE.md present** — does the project have a constitution to honor?
3. **Session carry-over readable** — does `state/session.md` exist and parse cleanly?
4. **Spawn primitive working** — issue one trivial test spawn (see `failure-protocol.md`).
5. **Tool environment** — `oj-helper` on PATH, required hooks installed.

Any failed check is surfaced to the user before the first user-facing action.

### Intake Funnel (External Input Processing)

When the session begins with new external input (issues, emails, meeting notes, Slack threads):

1. **Collect** — gather all inputs in one place (`state/intake.md` or inline).
2. **Deduplicate** — same item across channels gets one entry with all sources noted.
3. **Triage** — apply the two-dimensional triage to each. Some become backlog items; some are noise.
4. **Promote** — backlog-worthy items move to BACKLOG.md with the triage result attached.
5. **Confirm** — surface the resulting backlog deltas to the user before acting.

### Session Save (Pre-Clear Compression)

Before clearing context (`/clear`, end of session):

1. **Update BACKLOG.md** — mark items closed, deferred, in-progress with notes.
2. **Update session.md** — append today's carry-over; apply the aging policy to older entries.
3. **Promote candidates** — flag items that have survived three compressions as CLAUDE.md candidates (the human decides).
4. **Send queued comms** — clear the `comms-drafts.md` queue per signal gate.
5. **Log dev-mode feedback** — if `OJ_DEVMODE=1`, write the feedback file (see `dev-mode.md`).

After session save, context can be cleared without losing the thread.
