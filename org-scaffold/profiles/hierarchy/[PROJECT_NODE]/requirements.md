<!-- Hierarchy profile: [PROJECT_NODE]/requirements.md
     Resolve with: oj-helper resolve-path requirements --node [PROJECT_NODE] -->

# [PROJECT_NODE] -- Requirements

What must be true when this is done. Not how it works — that is `design.md`.

**Stable ids.** `FR-N` (functional) and `NFR-N` (non-functional), never
renumbered: they are the cross-reference keys that `design.md` and `plan.md`
cite, and renumbering silently repoints every citation.

## Functional

| Id | Requirement | Verification |
|----|-------------|--------------|
| FR-1 | [what the system must do, stated so that "is it done?" has a yes/no answer] | [how you would confirm it -- a command, a query, an observable behavior] |

## Non-functional

| Id | Requirement | Target | Verification |
|----|-------------|--------|--------------|
| NFR-1 | [latency / throughput / availability / durability / cost / operability] | [the number, with its unit] | [how the number gets measured] |

A non-functional requirement without a number is a preference. If the number is
not known yet, say so with `ASSERTED-UNVERIFIED` and name what would settle it,
rather than writing a number nobody measured.

## Out of scope

- [what this explicitly does NOT cover]

State this rather than leaving it implied. An unstated boundary is what scope
creep grows through, and it is the cheapest section here to write.

## Open questions

Unknowns that affect these requirements. Move each to
`../open-questions.md` if it outlives the drafting, so it is tracked where
questions are tracked rather than decaying at the bottom of this file.

- [Q] [the question, and what would settle it]
