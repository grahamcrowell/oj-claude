# Design: {Subject}

> Tier: {Moderate | Complex}  ·  Author: {name}  ·  Date: {YYYY-MM-DD}  ·  Requirements: {link to requirements.md, or "n/a — Moderate, design-first"}

<!-- Front-half authoring artifact, produced by the spec skill's `design` mode. -->
<!-- Derived from the requirements doc (Complex) or authored design-first (Moderate). Self-contained: name the concrete files and interfaces. -->

## Summary

[2-3 sentences: what the design does and the shape of the approach.]

## Requirements Satisfied

<!-- Trace each design element back to the FR/NFR it satisfies. Flag any requirement the design cannot meet back to reqs rather than papering over it. -->

- FR-1, FR-2 -> [how the design satisfies them]
- NFR-1 -> [how]

## Architecture

<!-- Name the concrete files, modules, and interfaces to be created or changed — a cold session must be able to act from this. -->

- Files / modules: [paths to create or change]
- Interfaces / contracts: [signatures, schemas, API shapes]
- Data / state: [stores, migrations, ownership]

```mermaid
%% Diagram where it clarifies the component or data flow.
```

## Key Decisions

<!-- Record what was chosen AND the alternatives rejected, so the decision is legible later. -->

| Decision | Chosen | Alternatives rejected | Why |
|----------|--------|-----------------------|-----|
| [D1] | [...] | [...] | [...] |

## Out of Scope

- [excluded item]

## Open Questions

- [ ] [question] — {owner / decision needed}

## Verification Approach

<!-- How the implemented design will be proven. This is the source for the implementation plan's per-task verification commands. -->

[Test strategy / build gate / observable outcome that demonstrates the design works end to end.]
