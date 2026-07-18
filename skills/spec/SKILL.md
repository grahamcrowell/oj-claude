---
description: Author front-half specs (reqs/design/plan) and graduate plan tasks into the backlog
disable-model-invocation: true
---

# /oj:spec

Author the front-half specification artifacts for a subject — requirements, then design, then implementation-plan — and **graduate** the plan's tasks into the backlog so `/oj:run-task` and `/oj:cycle` can execute them. This is the hand-rolled front half of the loop (Explore → Plan) that feeds the automated back half (Implement → Commit); it stops before any implementation.

**Invocation**: one argument selecting the mode — `reqs | design | plan | refresh`.

## Modes

| Mode | Reads | Produces |
|------|-------|----------|
| `reqs` | a short prompt | requirements doc (interview-first) |
| `design` | requirements doc | design doc |
| `plan` | design doc | implementation plan + **graduates** tasks to the backlog |
| `refresh` | a changed upstream artifact | re-aligned downstream docs + idempotent re-graduation |

## Ceremony scales to tier

Do not run all three docs for small work. Triage the subject per CONDUCTOR two-dimensional triage first:

- **Trivial** — no doc; do it directly (or via `/oj:run-task`).
- **Simple** — plan only; skip requirements/design.
- **Moderate** — design + plan.
- **Complex** — requirements + design + plan (all three earn their cost).

State the tier and which artifacts you will produce before authoring.

## Shared conventions (all modes)

- **Templates**: each mode authors against a template — copy and fill, do not invent structure:
  - `reqs` -> `${CLAUDE_PLUGIN_ROOT}/templates/requirements.md`
  - `design` -> `${CLAUDE_PLUGIN_ROOT}/templates/design.md`
  - `plan` -> `${CLAUDE_PLUGIN_ROOT}/templates/implementation-plan.md`
- **Location**: durable docs live under the project's `program/` artifacts area (e.g. `docs/program/<subject>-<artifact>.md`). Resolve the artifacts root with `oj-helper resolve-path artifacts` when writing to the OpenJunto state tree.
- **Self-contained**: each doc names the files and interfaces involved, states what is out of scope, and ends with an end-to-end verification step that proves the work.
- **Stable IDs**: requirements use `FR-N` / `NFR-N`; plan tasks use `T-<subject>-NN`. IDs are stable and never renumbered — they are the cross-reference and graduation keys.
- **Open questions**: surface unknowns explicitly; in `reqs` mode these are resolved by interview before drafting, not left as a post-hoc list.

## Mode: reqs — interview-first requirements

1. Start from the user's short prompt. **Do not one-shot the spec.** Interview the user with `AskUserQuestion`: dig into technical implementation, UX, edge cases, trade-offs, and out-of-scope boundaries — the hard parts they may not have considered. Keep interviewing until the material is covered.
2. Author the requirements doc against `${CLAUDE_PLUGIN_ROOT}/templates/requirements.md`: numbered functional requirements (`FR-N`) and non-functional requirements (`NFR-N`) with stable IDs; an explicit **Out of Scope** section; **Open Questions** (only those still genuinely open after the interview); and an **End-to-End Verification** statement (how the finished feature is proven).
3. Present the doc for review before proceeding. Do not auto-advance to `design`.

## Mode: design — architecture from requirements

1. Read the requirements doc. Author a design doc against `${CLAUDE_PLUGIN_ROOT}/templates/design.md`: reference the `FR-N`/`NFR-N` it satisfies; name the concrete files, modules, and interfaces to be changed or created; include an architecture sketch (a mermaid diagram where it clarifies); record key decisions and the alternatives rejected; restate **Out of Scope**; and give a **Verification Approach** that seeds the plan's per-task verify commands.
2. Flag any requirement the design cannot satisfy back to `reqs` rather than papering over it.
3. Present for review; do not auto-advance to `plan`.

## Mode: plan — tasks from design, then graduate

1. Read the design doc. Author the plan against `${CLAUDE_PLUGIN_ROOT}/templates/implementation-plan.md`, decomposing into numbered tasks `T-<subject>-NN`. Each task carries:
   - a title and a one-line scope;
   - `blockedBy:` — the `T-...` predecessors it depends on;
   - a **verification command** — the exact executable check that is green when the task is done (e.g. `uv run --extra dev pytest`, `mvn test`, `terraform validate && tflint`), not prose;
   - a size estimate;
   - optionally an explicit `priority:` field (overrides the derived priority at graduation).
2. Compute and record the **critical path**. Warn on any task estimated over ~1.5–2 dev-days and recommend splitting so each task maps to one review-sized PR (warn, do not block). Also warn (do not block) if a task's `verify:` command contains no assertion-bearing invocation - only `true`, `:`, `echo ...`, `exit 0`, or comments, with no test-runner/build/lint/validate call - and recommend a real check; such a command satisfies Deliver's requirement that a verification command be present and executed without proving the task is done.
3. Present the plan for review. Then run **Step G** to graduate the tasks.

### Step G — Graduate tasks to the backlog

Converts the plan's `T-<subject>-NN` tasks into backlog items `/oj:run-task` and `/oj:cycle` can select. This step WRITES shared state, so it prepares fully with no writes, gates on explicit confirmation, and commits all-or-none.

**G1 — Resolve the backlog source.** Run `oj-helper issue-tracker-check`; parse its JSON.
- `.configured == true` → **issue-tracker mode** (create issues; maintain the sidecar map).
- else → **file-backed mode**: `oj-helper resolve-path backlog` (fallback `.claude/BACKLOG.md` if it prints nothing).

**G2 — Derive priority per task.**
1. Compute the critical path from the plan's `blockedBy` graph. Critical-path tasks → higher band; off-path → one band lower; security / one-way-door tasks → top band.
2. If a task carries an explicit `priority:`, it overrides the derived band and breaks ties among equal bands. Emit the band representation the target backlog uses.

**G3 — Order and match.** Topologically sort tasks by `blockedBy`. For each, look up an existing item by `Source: <plan-doc>#T-<subject>-NN` (grep the backlog file, or `oj-helper issue-tracker-list` + the sidecar map). Classify each as **create**, **update** (matched item still `todo`/open), **hold** (matched item in progress or done — do not modify), or **cancel** (item whose plan task no longer exists).

**G4 — Build and validate the full set (NO writes).** Build every item entirely in memory, in the canonical backlog item schema (`${CLAUDE_PLUGIN_ROOT}/templates/backlog.md`):
- title ← task title; `AC` (acceptance) ← the task's verification command verbatim (`Verify: \`<cmd>\` passes`); `Links` ← the graduated ids of the task's `blockedBy` predecessors as `Blocked By` references plus any cited external artifact **as a reference, never a restated status** (they sort earlier, so their ids already exist); `Source:` ← `<plan-doc>#T-<subject>-NN`; priority ← G2; oversized tasks carry a `[oversized: consider splitting]` note.
- **Single-source discipline**: do not write a second copy of any external-state fact. If an item's `Status` asserts external state (e.g. a cited PR's state), stamp it `verified <today>`; otherwise link to the owning reference rather than caching its status. Graduation adds items that point, it does not duplicate.

Then validate the whole set: every predecessor resolves to an in-set or already-graduated id, no `Source:` collides, no id collides, every task that requires a verification command has one. **If any task fails validation, abort Step G now — write nothing, present nothing — and report the offending task(s).** Preparation reaches G5 only with a fully built, fully valid set.

**G5 — Confirmation gate (mandatory, whole-set).** Present the complete create / update / hold / cancel set as one diff-style summary via `AskUserQuestion`. Approval is for the batch as a whole — there is no per-item approval. **Write nothing until approved.** On rejection, report and stop; nothing is written.

**G6 — Commit atomically (all-or-none per plan).**
- **File-backed mode**: apply all creates/updates/cancels to an in-memory copy of the full backlog document, then write it in a **single replace** (write a temp file, then move it over the resolved backlog path). One write means no partial state is ever observable; if it fails, the original file is untouched. Cancels set `status: cancelled` — never delete. Preserve existing ids exactly.
- **Issue-tracker mode (emulated transaction)**: keep a run-staging list of every key created this invocation. Create issues via `oj-helper issue-tracker-create`, wire deps with `oj-helper issue-tracker-link-list`, and stage sidecar entries in memory. **If any create or link call fails, ROLL BACK**: close (or delete, per tracker capability) every key in the run-staging list, discard the staged sidecar entries, and report the batch as *not graduated* — the tracker is left exactly as before Step G. Only after every create and link succeeds, commit the sidecar map `<plan-doc>.map` in a single write. **Never** put a `T-<subject>-NN` or local backlog id in an issue's title/body/labels — the sidecar map is the only place the correspondence lives.

**G7 — Backlink the plan (only after G6 commits).** Write each task's graduated id back into the plan (`### T-<subject>-NN  -> <id>`). This forward-ref is what `refresh` reads to pull `done` status back into the plan. If G6 rolled back or the file write failed, do **not** touch the plan — the plan's forward-refs must never point at items that were rolled back.

## Mode: refresh — re-align downstream after an upstream change

1. Identify what changed (a requirement, a design decision, live PR/state drift) and which downstream artifacts it invalidates.
2. Re-align only the affected downstream docs (reqs → design → plan), preserving stable IDs so cross-references and graduated items still resolve.
3. Re-run **Step G**. Because graduation is keyed on `Source:`, re-graduation is idempotent: unchanged tasks are untouched, changed `todo` items update in place, new tasks are created, removed tasks are cancelled, and any changed task whose item is already in progress or done is surfaced as a user-only decision (re-opening is the user's call — never silently rewritten).

## Constraints

- **Front half only** — this skill authors specs and graduates tasks; it never implements. Implementation runs through `/oj:run-task` (one task) or `/oj:cycle` (loop the backlog).
- **Ceremony to tier** — do not produce all three docs for Simple/Trivial work.
- **Graduation is all-or-none per plan** — either the whole approved set is written or none is; a failure leaves the backlog source and sidecar map in their pre-graduation state.
- **Explicit confirmation before any backlog write** — never auto-write; present the full set first.
- **External-id hygiene** — plan-local `T-` ids and local backlog ids never appear in externally visible issue-tracker fields.
- If blocked or uncertain, stop and ask the user rather than guessing.
