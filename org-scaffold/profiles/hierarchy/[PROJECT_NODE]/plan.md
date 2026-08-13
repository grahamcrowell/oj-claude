<!-- Hierarchy profile: [PROJECT_NODE]/plan.md
     Resolve with: oj-helper resolve-path plan --node [PROJECT_NODE]
     Also this node's backlog: reached by backlog-glob=, read via backlog-list -->

# [PROJECT_NODE] -- Plan

Sequenced tasks for this node. **This file is also this node's backlog**: it is
matched by a `backlog-glob=` pattern in `.claude/oj-paths.env`, so
`oj-helper backlog-list` returns it and the backlog-reading skills aggregate it
with every other node's.

> **Ids are unique across the whole file set, not just this file.** Two items
> sharing one id make every inbound link resolve to whichever file is read
> first. `oj-helper backlog-lint` checks this; run it after adding items,
> especially when more than one session has been adding them the same day.

**Stable ids.** `T-[SUBJECT]-NN`, never renumbered — they are the graduation keys
that carry into the backlog as `Source:` back-references.

## Tasks

| Id | Task | Blocked by | verify: |
|----|------|-----------|---------|
| T-[SUBJECT]-01 | [what gets done] | -- | `[the command that proves it]` |
| T-[SUBJECT]-02 | [what gets done] | T-[SUBJECT]-01 | `[the command that proves it]` |

### On the `verify:` column

Each task carries a real check. A `verify:` of `true`, `:`, `echo done`, or
`exit 0` is trivially green and proves nothing — it turns the definition of done
into a formality. Name a test runner, a build, a lint, a query, or an
assertion-bearing command.

This value is copied **verbatim** into the backlog item's `AC` on graduation, so
a weak check here becomes a weak acceptance criterion there.

## Sequencing

[Why this order. The dependency graph above says what blocks what; this says
what would go wrong if the order were different -- which is the part a reader
cannot reconstruct.]

## Requirements traceability

Cite ids; do not restate the requirements.

| Task | Satisfies |
|------|-----------|
| T-[SUBJECT]-01 | FR-1 |

## Graduation record

Filled in when tasks graduate into the backlog. Graduation is idempotent, keyed
on `Source:`, and all-or-none per plan.

| Task | Backlog id | Graduated |
|------|-----------|-----------|
| T-[SUBJECT]-01 | [PREFIX]-NNN | [YYYY-MM-DD] |
