<!-- Hierarchy profile: backlog.md (root node)
     Scope: workspace-level items that belong to no single project node
     Resolve the set with: oj-helper backlog-list
     Check integrity with: oj-helper backlog-lint -->

# Backlog (root node)

Workspace-level items that belong to no single project node. Per-node work lives
in that node's own `backlog.md` or `plan.md`; this file is not an index of them.

> **This is one file in a set.** Under `layout=hierarchy` the backlog is split
> per owning node and enumerated by `backlog-glob=` in `.claude/oj-paths.env`.
> Read the whole set with `oj-helper backlog-list` and aggregate — reading this
> file alone shows workspace-level items only and omits every project's work
> **without saying so**.
>
> **Ids are unique across the entire set, not just this file.** An id is the
> cross-reference key: two items sharing one id make every inbound link resolve
> to whichever file is read first. Run `oj-helper backlog-lint` to check that,
> plus duplicate anchors and within-file duplicates — all three are invisible to
> a human reading the files and cheap for a machine to find.

> Prefix `[PREFIX]-NNN` (pick one scheme and keep it stable, e.g. `L-071`).
> **Item format:** each open item carries `Status` / `Urgency` / `AC` / `Links` /
> `Context`. Closed items collapse to a one-line marker.
> **Urgency vocabulary:** `currently-blocking` (blocks work or people today) --
> `eventual-blocker` (hard gate later; start before it bites) -- `aspirational`
> (quality/hygiene, no gate) -- `dated <YYYY-MM-DD>` (calendar deadline).
> **Freshness:** any `Status` asserting external state (PR / branch / ticket)
> carries a `verified <YYYY-MM-DD>` stamp. Treat an un-dated status word as
> suspect by construction.

<!--
SINGLE-SOURCE DISCIPLINE

  A fact about any external artifact's state -- a PR being open/merged/closed, a
  branch existing, a ticket's status -- is asserted in EXACTLY ONE place: the
  owning item's `Status` line, with a `verified <date>` stamp.

  Every other table REFERENCES the item by id and never restates its external
  state. Write `-> see [PREFIX]-120`, not a second copy of the status word that
  can drift out of sync with the first.

  Why: the same fact stored twice, with nothing forcing the copies to agree, is
  how a backlog goes stale even under careful audits -- one edit touches one copy
  and the other rots. Point, do not duplicate.

  This matters MORE under a split backlog, not less: there are now several files
  that could each hold a stale copy of the same external state.

  When this file grows past ~500-600 lines, run the compaction skill. Compaction
  operates per file and never merges files -- splitting is the user's structural
  decision, not a hygiene side effect.
-->

---

## Workstreams

<!-- Pointer index. The `Items` column lists ids only -- never PR/ticket state
     words. Link to the item, whose Status line is authoritative. -->

| WS | Goal | Current bottleneck | Items |
|----|------|--------------------|-------|
| [A -- [short name]](#ws-a) | [the done-state this workstream drives toward] | [the single thing blocking progress right now, by item id] | [ids] |

---

<a id="ws-a"></a>
### WS-A -- [short name]

> Goal: [the concrete done-state]. Sequencing: [id] -> [id] ([one line on why
> this order]).

- **[PREFIX]-001** -- [title] (added [YYYY-MM-DD])
  - Status: [the single authoritative state of this item] (verified [YYYY-MM-DD])
  - Urgency: [currently-blocking | eventual-blocker | aspirational | dated <YYYY-MM-DD>] -- [one-line justification]
  - AC: [acceptance criteria / definition of done; if graduated from a plan, the task's `verify:` command lands here verbatim]
  - Links: [blocked-by <id>; blocks <id>; external artifacts as links]
  - Context: [why this exists, if not obvious from the title]

---

## Closed

- **[PREFIX]-000** -- [title] -- done [YYYY-MM-DD]
