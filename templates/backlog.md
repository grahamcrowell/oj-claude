# Local Backlog

> Local task graph for `<project>`. Prefix `<PREFIX>-NNN` (pick one scheme and keep it stable, e.g. `L-071`, `BACK-12`).
>
> This file is the user's own task graph: sequencing, "why blocked", acceptance criteria, and cross-item links -- the things no issue tracker, PR, or doc records. It is a THIN layer of pointers plus personal reasoning over GitHub / the issue tracker / external docs, NOT a cache of their state. See "Single-source discipline" below.
>
> **Item format:** each open item carries `Status` / `Urgency` / `AC` / `Links` / `Context`. Closed items collapse to a one-line marker.
> **Urgency vocabulary:** `currently-blocking` (blocks work or people today) - `eventual-blocker` (hard gate later; start before it bites) - `aspirational` (quality/hygiene, no gate) - `dated <YYYY-MM-DD>` (calendar deadline).
> **Freshness:** any `Status` that asserts external state (PR/branch/ticket) carries a `verified <YYYY-MM-DD>` stamp. Treat an un-dated status word as suspect by construction.
> **Organization:** open items group into workstreams below; each states its goal, sequencing, and current bottleneck. Closed/retired items keep their own sections.

<!--
SINGLE-SOURCE DISCIPLINE (the rule that keeps this file a source of truth):

  A fact about any external artifact's state -- a PR being open/merged/closed,
  a branch existing, an issue-tracker ticket's status -- is asserted in EXACTLY
  ONE place: the owning item's `Status` line, with a `verified <date>` stamp.

  Every other table (the Workstreams index, the Open PR Register, any
  task-number -> item map) REFERENCES the item by id and never restates its
  external state. Write `-> see L-120`, not a second copy of the status word
  that can drift out of sync with the first.

  Why: the same fact stored twice with nothing forcing the copies to agree is
  how a backlog goes stale even under careful audits -- one edit touches one
  copy and the other rots. Point, do not duplicate.

  Narrative belongs elsewhere: multi-paragraph implementation logs, commit
  SHAs, and design rationale live in commit messages, PR descriptions, and
  session.md -- not here. This file answers only "what is the state" and "what
  is the blocker". When an item's entry grows past a few lines of that, move
  the narrative out. When the whole file grows past ~500-600 lines (or a single
  Read needs more than one page), run the compaction skill.
-->

---

## Workstreams

<!-- Index table. The `Items` column lists ids only; it is a pointer index, not
     a status cache. Do NOT put PR/ticket state words in this table -- link to
     the item, whose Status line is authoritative. -->

| WS | Goal | Current bottleneck | Items |
|----|------|--------------------|-------|
| [A -- {short name}](#ws-a) | {the done-state this workstream drives toward} | {the single thing blocking progress right now, by item id} | {ids} |
| [B -- {short name}](#ws-b) | {goal} | {bottleneck} | {ids} |

---

<a id="ws-a"></a>
### WS-A -- {short name}

> Goal: {the concrete done-state}. Sequencing: {id} -> {id} -> {id} ({one line on why this order}).

- **{PREFIX}-001** -- {title} `[subject: {tag}]` (added {YYYY-MM-DD})
  - Status: {the single authoritative state of this item} (verified {YYYY-MM-DD})
  - Urgency: {currently-blocking | eventual-blocker | aspirational | dated <YYYY-MM-DD>} -- {one-line justification}
  - AC: {acceptance criteria / definition of done; if graduated from a plan, the task's `verify:` command lands here verbatim}
  - Links: {blocked-by <id>; blocks <id>; external artifacts as links -- PRs, tickets, docs}
  - Source: {<plan-doc>#T-<subject>-NN when graduated from an implementation plan; omit otherwise}
  - Context: {optional -- rationale a future reader needs that is not obvious from the above}

- **{PREFIX}-002** -- {title} `[subject: {tag}]` (added {YYYY-MM-DD})
  - Status: {state} (verified {YYYY-MM-DD})
  - Urgency: {vocabulary} -- {justification}
  - AC: {definition of done}
  - Links: {deps + artifacts}

<a id="ws-b"></a>
### WS-B -- {short name}

> Goal: {done-state}. Sequencing: {order + one-line rationale}.

- **{PREFIX}-003** -- {title} `[subject: {tag}]` (added {YYYY-MM-DD})
  - Status: {state} (verified {YYYY-MM-DD})
  - Urgency: {vocabulary} -- {justification}
  - AC: {definition of done}
  - Links: {deps + artifacts}

---

## Open PR Register (optional)

<!-- Only worth keeping when there are open PRs with NO owning backlog item
     (e.g. teammate PRs you are tracking). For any PR that DOES have an item,
     the item's Status line is authoritative -- do not duplicate it here.
     This table is a dated snapshot, not live-authoritative: state it says so. -->

> Snapshot as of {YYYY-MM-DD} (refresh with your PR-list command, e.g. `gh search prs --owner <org> --state open`). Not live-authoritative; for any PR with an owning item, that item's Status line wins on disagreement.

| PR | Title | State (snapshot) | Owning item |
|----|-------|------------------|-------------|
| {org/repo#N} | {title} | {open/merged/closed as of snapshot date} | {item id, or "none"} |

---

## Completed / Retired

<!-- Closed items collapse to a one-line marker. Keep for reference; full
     history lives in git and in the commit/PR that closed them. -->

- ~~{PREFIX}-000~~ -- {title} -- done {YYYY-MM-DD} ({PR/commit/ticket that closed it})
