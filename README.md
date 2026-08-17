# OpenJunto for Claude Code

A Claude Code configuration that transforms the AI into a coordinated team of 16 expert sub-agents with structured peer review.

## Quickstart

OpenJunto ships as a Claude Code plugin — no build step. Install it from the marketplace inside a Claude Code session:

```
/plugin marketplace add openjunto/oj-claude
/plugin install oj@openjunto
```

Then start a new Claude Code session (restart, or `/clear`) to load the plugin. To iterate on the plugin locally without installing it, load the working tree directly:

```bash
git clone https://github.com/grahamcrowell/oj-claude.git
claude --plugin-dir ./oj-claude
```

On the next session start, you should see a banner on stderr:

```
OpenJunto v<version> active — OpenJunto coordination system
```

The banner is printed by the `SessionStart` hook, so it appears on session start (startup, resume, `/clear`, compaction) — not on `/reload-plugins` or `/plugin reload`. After a reload, start a new session to see it. `<version>` comes from this repo's `VERSION` file.

## Usage

The manager protocol loads at session start. Put OpenJunto to work by invoking a coordinated cycle with `/oj:cycle <what you want done>` (or `/oj:run-task` for a backlog item):

- `/oj:cycle Review this pull request for security issues.`
- `/oj:cycle Fix the flaky test in auth_service_test.go.`
- `/oj:cycle Evaluate whether we should migrate from REST to gRPC for internal services.`

The Manager handles triage, expert selection, peer review, and quality gates. You don't invoke experts by name — the Manager selects them.

### Commands

| Command | What it does |
|---------|--------------|
| `/oj:cycle` | Loop the backlog: triage, delegate, review, test, commit, per item |
| `/oj:run-task` | Run exactly one backlog item through the 5-phase lifecycle, locally |
| `/oj:impl <project/domain> [id]` | Deliver one item as a reviewed **draft PR**: branch, lifecycle, push gate, PR |
| `/oj:watch-pr <pr>` | Watch an open PR through CI and review until a human merges, then close out the item |
| `/oj:review [--fix] [--comment] <path\|pr>` | Adversarially review a path or PR; file findings; optionally fix confirmed ones or post them |
| `/oj:spec <op> <project/domain> [id]` | Author requirements / design / plan for a subject and graduate its tasks (`reqs\|design\|plan\|refresh\|capture`) |
| `/oj:show-backlog` | Read-only backlog summary by priority |
| `/oj:save-session` | Persist session state before `/clear` |
| `/oj:backlog-compact` | Size-triggered backlog hygiene |
| `/oj:workstream-new` | Scaffold an isolated parallel execution thread |
| `/oj:health-check` | Diagnose plugin runtime health |

Delivery is split on purpose: `/oj:impl` stops at the draft PR, and `/oj:watch-pr` carries it the rest of the way. Waiting on CI and on a human reviewer is open-ended, so it belongs in a command you can re-invoke rather than inside the one that wrote the code.

## What's Included

- **16 expert agents** — full + compact profiles in [`agents/`](agents/)
- **Templates** — technical analysis, ADR, retrospective, session state, comms playbook ([`templates/`](templates/))
- **Complexity triage** — Simple / Moderate / Complex tiers with process weight proportional to risk
- **Peer review workflow** — adversarial review by a different domain on all Moderate/Complex work
- **Circuit breakers** — auto-escalate after 3 revision cycles or 2 hours without progress

## How It Works

1. **Triage** — Incoming requests scored against 4 criteria (multi-domain, regulatory, production risk, resource commitment)
2. **Delegation** — Manager spawns domain experts via the Task tool
3. **Review** — A different expert adversarially reviews the work, testing failure modes
4. **Synthesis** — Manager consolidates findings, surfaces dissenting views, hands back to you

## Advanced: Backlog Sprint

For projects with a file-backed backlog (`oj-helper resolve-path backlog`, `.claude/BACKLOG.md` by default), run:

```bash
claude '/run-task'
```

The Manager picks the next item, delegates to experts, enforces peer review, and marks it done.

## Directory Structure

The plugin tree (loaded by the plugin host from this repo's root):

```
.claude-plugin/
└── plugin.json              # Plugin manifest

CONDUCTOR.md                 # Manager coordination protocol (injected at SessionStart)
agents/                      # 16 full + 16 compact expert profiles
skills/                      # /run-task, /show-backlog, /save-session, /cycle
templates/                   # Structured output formats
reference/                   # Tier-loaded background (workflow, stakeholders, examples)
hooks/
└── hooks.json               # SessionStart + SubagentStart wiring
bin/
└── oj-helper                # Hook dispatcher + backlog helpers
```

Per-project, OpenJunto reads and writes a local `.claude/` directory:

```
.claude/
├── CLAUDE.md                # Project-local protocol overrides (optional)
├── BACKLOG.md               # Project backlog (consumed by /run-task)
├── state/                   # Session state, carry-over notes
└── artifacts/               # Generated deliverables (ADRs, analyses, retrospectives)
```

## Documentation

- [WHY.md](WHY.md) — the problem OpenJunto solves, concrete examples, honest tradeoffs
- [docs/onboarding.md](docs/onboarding.md) — your first 10 minutes after installation
- [CONDUCTOR.md](CONDUCTOR.md) — the full Manager protocol
- [reference/expert-index.md](reference/expert-index.md) — expert roster and engagement triggers
