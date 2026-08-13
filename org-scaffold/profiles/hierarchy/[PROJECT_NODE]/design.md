<!-- Hierarchy profile: [PROJECT_NODE]/design.md
     Resolve with: oj-helper resolve-path design --node [PROJECT_NODE] -->

# [PROJECT_NODE] -- Design

How it works and why it is shaped that way. This file answers **"what is the
current design?"** — keep it current rather than appending revisions, and it will
keep answering that.

> **This is not a review.** Point-in-time findings about existing work belong in
> a history area, not here. If a review concludes with new intent, split it: the
> findings go to history, the intent lands in this file. Conflating the two is
> how genuine design content ends up buried in a dated folder nobody cites.

## Overview

[What this is, in a few sentences. Name the files and interfaces involved -- a
design that does not say where the code lives cannot be acted on.]

## Requirements covered

Cite by id, do not restate. Restating is how the two files drift apart.

- FR-1, FR-2, NFR-1 -> [which part of this design satisfies them]

## Structure

[Components and their responsibilities. Name the actual modules, services, and
interfaces.]

## Key design decisions

Summarize each here and record it in `decisions.md` — that file is the
authoritative log; this is the reader's-eye view. Link, do not duplicate the
rationale.

| Decision | Why | Recorded |
|----------|-----|----------|
| [the choice] | [the constraint that forced it] | [link into decisions.md] |

## Failure modes

[How this breaks, and what happens when it does. A design that documents only
the happy path has not been designed yet -- this section is where the real
review pressure lands.]

| Failure | Effect | Handling |
|---------|--------|----------|
| [what goes wrong] | [blast radius] | [detection and response] |

## Out of scope

- [what this design deliberately does not address]

## Verification

[The end-to-end check that proves this works -- a command to run, a query, an
observable outcome. Name it concretely: "tests pass" is not a verification step.]
