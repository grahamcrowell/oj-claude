# Changelog

## v0.0.10 — 2026-07-08

**Provenance**: hand-cut (no juntogen regen). Scope: retire the haiku/sonnet/opus three-tier model roster in favor of a two-tier fable / opus[1m] roster, all spawns targeting `xhigh` effort.

**Preserved hand-cut**:
- `CONDUCTOR.md` § Model Selection — `opus` → `fable`; `sonnet` and `haiku` → `opus[1m]`. Tier table collapses to two rows: **opus[1m]** (implementation — absorbs the former routine and implementation tiers, cost ratio 1.0× baseline) and **fable** (reasoning, 2.0×). Function rules updated: adversarial reviewer slot and Complex-tier lead → `fable`; Moderate lead, Phase-1 analysts, deputy coordinator, and domain-trigger specialists → `opus[1m]`, escalating to `fable` on the same conditions as before. Per-role default table merged to two rows (the Technical Writer haiku default and its sonnet-escalation clause are gone — everything non-fable is `opus[1m]`). § Effort rewritten: target effort for all spawns is **`xhigh`**, applied session-level (per-spawn effort still isn't exposed by the Task tool).
- `platform-defaults.yaml` — models list replaced: `fable` / `claude-fable-5` and `opus[1m]` / `claude-opus-4-8[1m]` (1M context, 128K output each, `effort: "xhigh"`); cost_ratio rebaselined to opus[1m] = 1.0 (Opus 4.8 $5/MTok input vs Fable 5 $10/MTok). Header MODEL IDs note and description updated; file version 1.0.0 → 2.0.0.
- `skills/cycle/SKILL.md`, `skills/run-task/SKILL.md` — terse function-rule callouts (Moderate and Complex branches) updated to the new roster + xhigh note.
- `skills/sandbox-cycle/SKILL.md`, `skills/delegate-sandbox/SKILL.md` — host adversarial review model `opus` → `fable`.
- `reference/worked-examples.md` — Example 2 spawn prompts: analysts/implementer `model: sonnet` → `model: opus[1m]`; reviewer `model: opus` → `model: fable`.

**DATA artifacts**:
- `VERSION` (0.0.9 → 0.0.10)
- `.claude-plugin/plugin.json` (version 0.0.9 → 0.0.10)

## v0.0.9 — 2026-06-25

**Provenance**: hand-cut (no juntogen regen). Scope: drop the auto-detected `.claude/local/` canonical-state-root layout from `resolve-path` so it never points at nonexistent `local/` paths.

**Preserved hand-cut**:
- `bin/oj-helper` — `resolve-path` no longer probes for `.claude/local/`. The all-or-nothing local-vs-legacy layout switch is removed; oj state is always the layout directly under `.claude/` (`.claude/state/session.md`, `.claude/BACKLOG.md`, `.claude/artifacts`, `.claude/state`, `.claude`, `.claude/archive/retros`). A project that must relocate state still does so per-key via `.claude/oj-paths.env`, which wins over the default. `$OJ_STATE_ROOT` now means the workspace root directly, tolerating a trailing `/.claude/local` or `/.claude` suffix for hooks written against older releases.
- `bin/oj-helper` — `workstream-new` (`_workstream_resolve_workspace`, `_workstream_link_all`, the generated per-workstream `.claude/CLAUDE.md`) migrated off `.claude/local/...`: the workspace marker is now `.claude/state/session.md`, and the shared symlinks are `state/session.md`, `BACKLOG.md`, and `artifacts` directly under `.claude/` — matching what every skill now resolves.
- `reference/file-patterns.md`, `skills/workstream-new/SKILL.md`, `skills/save-session/SKILL.md`, `juntogen/claude/step-01-workstream-new.md` — describe the single `.claude/` layout (relocate via `oj-paths.env`) instead of the removed `.claude/local/` canonical-state-root.
- `scripts/tests/oj-helper-hook-test.sh` — S15 workstream fixtures and assertions use the legacy `.claude/state/session.md` marker. Full suite: 64/64.

**DATA artifacts**:
- `VERSION` (0.0.8 → 0.0.9)
- `.claude-plugin/plugin.json` (version 0.0.8 → 0.0.9)

## v0.0.8 — 2026-06-23

**Provenance**: hand-cut (no juntogen regen). Scope: make the sandbox skills' pre-flight allowlist-friendly so it stops prompting on every run.

**Preserved hand-cut**:
- `skills/sandbox-cycle/SKILL.md`, `skills/delegate-sandbox/SKILL.md` — replaced the
  vague inline pre-flight prose (which made the model improvise a different compound
  shell command each run that the permission allowlist could never match) with a
  single fixed-name command, `"$CLAUDE_SANDBOX_DIR/scripts/sandbox-preflight.sh"`
  (lives in the `claude-sandbox` repo). The skills run it verbatim, parse its JSON,
  stop the loop on `.ok == false`, and surface `.blockers`. Removes the recurring
  **pre-flight** permission prompt — allowlist once with
  `Bash(*/scripts/sandbox-preflight.sh)`; the per-item worker dispatch is separately
  allowlistable with `Bash(*/scripts/oj-worker.sh*)`.

**DATA artifacts**:
- `VERSION` (0.0.7 → 0.0.8)
- `.claude-plugin/plugin.json` (version 0.0.7 → 0.0.8)

## v0.0.7 — 2026-06-21

**Provenance**: hand-cut (no juntogen regen). Scope: a looping cycle variant that delegates implementation to sandbox containers.

**Preserved hand-cut**:
- `skills/sandbox-cycle/SKILL.md` — new `/oj:sandbox-cycle` skill. Runs the `/oj:cycle` backlog loop verbatim but delegates each item's **Phase 2 implementation** to a disposable `claude-sandbox` container worker (via `/oj:delegate-sandbox` / `$CLAUDE_SANDBOX_DIR/scripts/oj-worker.sh`); stakeholder analysis, adversarial review, testing, commits, and retros stay on the host. Adds a triage gate that stops items needing host-only capabilities (AWS/Terraform/VPN/marqeta-git) for plain `/oj:cycle`, and keeps commit authority + the clean-tree gate on the host.

**DATA artifacts**:
- `VERSION` (0.0.6 → 0.0.7)
- `.claude-plugin/plugin.json` (version 0.0.6 → 0.0.7)

## v0.0.6 — 2026-06-21

**Provenance**: hand-cut (no juntogen regen). Scope: a host-side skill for delegating isolated execution to a sandbox container.

**Preserved hand-cut**:
- `skills/delegate-sandbox/SKILL.md` — new `/oj:delegate-sandbox` skill. Hands one self-contained implementation task to a disposable `claude-sandbox` container worker (plain Claude Code, no oj plugin inside) via `$CLAUDE_SANDBOX_DIR/scripts/oj-worker.sh`, then has the manager review the diff on the host and land it. The worker carries the sandbox's PR guardrail (open a PR, never approve/merge/label/force-push), so merge authority stays on the host. Preserves the delegation boundary (the worker is the implementer) and pairs with `/oj:workstream-new` for per-worktree parallel isolation.

**DATA artifacts**:
- `VERSION` (0.0.5 → 0.0.6)
- `.claude-plugin/plugin.json` (version 0.0.5 → 0.0.6)

## v0.0.5 — 2026-06-20

**Provenance**: hand-cut (no juntogen regen). Scope: close the one state path the skills did not route through `resolve-path`.

**Preserved hand-cut**:
- `bin/oj-helper` — `resolve-path` gains a `retros` key (`legacy:retros → .claude/archive/retros`, `local:retros → .claude/local/archive/retros`). Additive; existing keys and their defaults are unchanged. Honors `oj-paths.env` overrides like every other key.
- `skills/run-task/SKILL.md`, `skills/cycle/SKILL.md` — Complex-tier retrospectives now write to `oj-helper resolve-path retros` (literal `.claude/archive/retros/` fallback) instead of hardcoding the path. This was the only state path the skills still hardcoded; consumers that relocate state (e.g. a project whose retros belong under its artifacts tree) can now redirect it.

**DATA artifacts**:
- `VERSION` (0.0.4 → 0.0.5)
- `.claude-plugin/plugin.json` (version 0.0.4 → 0.0.5)

## v0.0.4 — 2026-06-20

**Provenance**: hand-cut (no juntogen regen). Scope: a path-resolution layer so skills defer to the host project's state layout, plus a delegation-boundary scope clause.

**Preserved hand-cut**:
- `bin/oj-helper` — new `resolve-path <key>` subcommand (keys: `session`, `backlog`, `artifacts`, `state-dir`, `config`). Resolves the workspace root (`--workspace` → `$OJ_STATE_ROOT` → `.claude/` walk-up → `$PWD`), auto-detects layout (`local` when `.claude/local/` exists, else `legacy`), honors per-key overrides in `<root>/.claude/oj-paths.env`, and echoes one absolute path. Pure resolution — never creates the path. Vanilla `.claude/` defaults are unchanged.
- `skills/save-session`, `skills/show-backlog`, `skills/run-task`, `skills/cycle` — resolve `session`/`backlog`/`artifacts` paths via `resolve-path` instead of hardcoding `.claude/state/session.md`, `.claude/BACKLOG.md`, `.claude/artifacts/`; each carries a literal-path fallback. Backlog ID parsing is now prefix-agnostic (no longer assumes a `BACK-` prefix; matches any `<PREFIX>-<N>`, e.g. `L-071`).
- `CONDUCTOR.md` — Delegation Boundary gains a **SCOPE** clause: it binds inside `/oj:cycle` / `/oj:run-task` and at Moderate/Complex tier, and explicitly does not bind free-form requests, Simple-tier work, or host projects whose `.claude/CLAUDE.md` defines a hands-on engineering workflow (project instructions take precedence). Templates table + responsibilities line reference `resolve-path`.
- `reference/file-patterns.md` — doc-wide callout that its `.claude/...` paths are `legacy`-layout defaults and `resolve-path` is the runtime source of truth.

**DATA artifacts**:
- `VERSION` (0.0.3 → 0.0.4)
- `.claude-plugin/plugin.json` (version 0.0.3 → 0.0.4)

## v0.0.3 — 2026-06-19

**Provenance**: hand-cut (no juntogen regen). Scope limited to workstream-new workspace resolution and the embedded workstream `CLAUDE.md` template path conventions.

**Preserved hand-cut**:
- `bin/oj-helper` — `_workstream_resolve_workspace` now honors `$OJ_STATE_ROOT` as a third resolution step (after `--workspace`, before `$PWD` walk-up). A SessionStart hook can export it to pin the canonical workspace when sessions launch from a subrepo or worktree. `_workstream_link_all` migrated to link `local/backlog/BACKLOG.md` and `local/artifacts/` (was top-level `BACKLOG.md` and `artifacts/`) — matches the `.claude/local/` canonical layout introduced in v0.0.2's d79652e.
- `bin/oj-helper` — embedded workstream `CLAUDE.md` template and the workstream-new resolver error message updated to reference the new paths and the `OJ_STATE_ROOT` env var.

**DATA artifacts**:
- `VERSION` (0.0.2 → 0.0.3)
- `.claude-plugin/plugin.json` (version 0.0.2 → 0.0.3)

## v0.0.2 — 2026-05-13

**Provenance**: regenerated by the juntogen pipeline from juntospec v0.0.2 (no hand-cut changes).

**DATA artifacts** (byte-identical to baseline):
- `.claude-plugin/plugin.json` (version 0.0.1 → 0.0.2)
- `hooks/hooks.json`
- `bin/lib/contracts.sh`
- `platform-defaults.yaml`

**PROSE artifacts** (regen-produced; shape verified via structural-diff + Tier A):
- CONDUCTOR.md, agents/*, skills/*, reference/*, templates/*, docs/*, bin/oj-helper, README.md, WHY.md, org-scaffold/*

**Preserved hand-cut**:
- VERSION (bumped separately to track release boundary)
- LICENSE, .gitignore, .github/workflows/plugin-validate.yml, .claude/CLAUDE.md

**Known calibration**:
- plugin-e2e-test T2 byte-budget tolerance widened from +/-64 to +/-512 to accommodate PROSE-class regen drift (oj-claude commit 6c5c992).

## v0.0.1 — 2026-04-17

Initial hand-cut baseline. Tagged `oj-claude-v0.0.1-handcut-baseline`.
