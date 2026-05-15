# Communications Playbook — {Project Name}

<!--
This is the playbook at `.claude/COMMS.md`. Use it for projects with multiple stakeholder channels where communication fatigue is a real risk. The three load-bearing sections are the Signal Gate (decides *whether* to post), the Hierarchy Rule (decides *how many times*), and the Channel Routing table (decides *where* to post).
-->

---

## Signal Gate

<!--
The gate prevents noise. Communication is warranted ONLY on change events — not elapsed time. A status update triggered by "it's been a week" is almost always a restatement of current state and should not be sent.
-->

| Signal | Post to |
|--------|---------|
| Acceptance criterion completed | {Ticket system, team channel} |
| Blocker discovered | {Ticket system, stakeholder channel} |
| Blocker resolved | {Same channel where blocker was posted} |
| Status transition (e.g., In Progress → In Review → Done) | {Ticket system} |
| Decision made (trade-off, scope change, direction) | {Stakeholder channel, decision log} |
| Story / task completed | {Ticket system, team channel} |
| Health status shift (Green → Yellow, Yellow → Red) | {Stakeholder channel, status doc} |
| Ask / escalation needed (unblock, approval, resource) | {Stakeholder channel with direct mention} |

### Not a signal

<!-- These do not justify a post. Resist the urge. -->

- **Elapsed time** — "It's been N days" is never, by itself, a reason to communicate.
- **Internal housekeeping** — Refactors, test additions, doc fixes visible in the repo.
- **Current-state restatement** — Nothing has changed since the last update.
- **Work-in-progress without milestone** — Progress that hasn't crossed a status boundary or completed an acceptance criterion.

---

## Hierarchy Rule

> **One event = one post at the lowest appropriate level.** Only roll up when the aggregated picture changes.

<!--
Example: A single acceptance criterion completing belongs in the ticket comment. It does NOT get echoed to the team channel, the stakeholder channel, and the weekly status doc. The team channel cares when the *story* completes; the stakeholder channel cares when the *milestone* shifts; the status doc cares when the *health* changes.

Don't echo the same news at multiple levels. Every duplicate post degrades the signal value of that channel.
-->

- **Task level** → ticket system only.
- **Story level** → roll up to team channel once the whole story crosses a status boundary.
- **Milestone level** → roll up to stakeholder channel when the milestone moves or slips.
- **Health level** → roll up to status doc / meeting when Green/Yellow/Red shifts.

Cross-posting is allowed only when distinct audiences would otherwise miss a change they need to act on.

---

## Channel Routing

| Channel | Purpose | Trigger | Format |
|---------|---------|---------|--------|
| {Ticket system — e.g., Linear, Jira} | Source of truth for work items | Any status/AC change | Structured fields + short comment |
| {Team channel — e.g., #eng-team} | Technical peers, async coordination | Story completion, blocker, decision affecting the team | Terse, link to ticket |
| {Stakeholder channel — e.g., #project-foo} | Product partners, sponsors | Milestone shift, health change, ask | Outcome-focused, no jargon |
| {Status doc / meeting — e.g., weekly review} | Leadership visibility | Health change, risk emergence, ask | Narrative + metrics |

<!-- Add rows for additional channels (PagerDuty, customer comms, external partners). Delete rows that don't apply. -->

---

## Drafts

<!--
Queue of communications pending review. Review at session save. Expand each draft inline for review using the format:

  <!-- DRAFT START: {channel} / {YYYY-MM-DD} -->
  {Full text of the draft message}
  <!-- DRAFT END -->

Status values: Draft | Reviewed | Sent | Cancelled.
-->

| Date | Channel | Draft | Status |
|------|---------|-------|--------|
| {YYYY-MM-DD} | {Channel} | {One-line summary — full text expanded below} | Draft |

<!-- DRAFT START: {Channel} / {YYYY-MM-DD} -->
{Full draft text goes here, ready for copy-paste once approved.}
<!-- DRAFT END -->

---

## Log

<!--
Per-channel append-only record. Survives beyond the retention window of the channels themselves. Useful for audit, onboarding new stakeholders, and catching hierarchy-rule violations.
-->

### {Ticket system}

| Date | Summary |
|------|---------|
| {YYYY-MM-DD} | {What was communicated — link to comment/thread} |

### {Team channel}

| Date | Summary |
|------|---------|
| {YYYY-MM-DD} | {Summary} |

### {Stakeholder channel}

| Date | Summary |
|------|---------|
| {YYYY-MM-DD} | {Summary} |

### {Status doc / meeting}

| Date | Summary |
|------|---------|
| {YYYY-MM-DD} | {Summary} |
