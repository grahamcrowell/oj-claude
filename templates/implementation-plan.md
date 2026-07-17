# Implementation Plan: {Subject}

> Tier: {Simple | Moderate | Complex}  ·  Author: {name}  ·  Date: {YYYY-MM-DD}  ·  Design: {link to design.md, or "n/a — Simple, plan-only"}

<!-- Front-half authoring artifact, produced by the spec skill's `plan` mode. -->
<!-- Decompose the design into review-sized tasks, then graduate them into the backlog (Step G) so /oj:run-task and /oj:cycle can execute them. -->

## Summary

[2-3 sentences: what gets built and the delivery shape.]

## Tasks

<!--
Stable IDs T-{subject}-NN — never renumber; they are the graduation keys (Source: back-ref).
Each task = one review-sized PR. Each carries:
  - blockedBy: the T-IDs it depends on (translated to Blocked By at graduation, enforcing the critical path)
  - verify:   the exact executable check that is green when the task is done (the definition-of-done)
  - size:     estimate; warn/split if over ~1.5-2 dev-days so each task maps to one PR
  - priority: OPTIONAL — overrides the critical-path-derived priority at graduation, and breaks ties
-->

### T-{subject}-01 — [title]
- blockedBy: [none]
- verify: `[exact command that passes when this task is done]`
- size: [S | M | L | ~Nd]
- priority: [optional]
- [one-line scope]

### T-{subject}-02 — [title]
- blockedBy: T-{subject}-01
- verify: `[command]`
- size: [S | M | L | ~Nd]
- [one-line scope]

## Critical Path

<!-- The ordered T-IDs on the critical path — drives the derived priority band at graduation. -->

[T-{subject}-01 -> T-{subject}-02 -> ...]

## Risk Register

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| [risk] | [H/M/L] | [H/M/L] | [mitigation] |

## Live-State Reconciliation

<!-- Plans drift between authoring and execution. Re-verify at each task kickoff in fresh context before writing code. -->

- [ ] Cited PRs / live state re-checked against reality: {YYYY-MM-DD}

## Graduation Record

<!-- Written by the spec skill's Step G after graduation. Bidirectional link: plan task <-> backlog id. Re-graduation (refresh) syncs this by Source: back-ref. -->

| Task | Backlog id | Status |
|------|-----------|--------|
| T-{subject}-01 | {L-NN / tracker key} | {todo | in progress | done} |
| T-{subject}-02 | {L-NN / tracker key} | {todo | in progress | done} |
