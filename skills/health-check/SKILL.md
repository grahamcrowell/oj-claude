---
name: health-check
description: Diagnose OpenJunto plugin runtime health — verify CONDUCTOR.md injection, oj-helper availability, jq dependency, plugin manifest, SubagentStart hook wiring.
allowed-tools: [Bash, Read, Grep, Glob]
context: fork
---

# /oj:health-check

Empirical runtime probe of the OpenJunto plugin install. This skill is **not** a structural file-reading audit (that lives in `scripts/validate-plugin.sh`). Instead, it invokes real `oj-helper` subprocesses, captures their stdout/stderr/exit codes, and reports what the runtime actually does — proof of liveness, not proof of layout.

> Run this when an adopter reports "the manager protocol does not seem to be loaded" or "expert profiles are not being injected". It distinguishes broken wiring from misconfigured environment.

## Protocol

Execute the following commands **in order** using the Bash tool. Capture stdout, stderr, and exit code for each, and report them under a header per probe. Do **not** paraphrase the outputs — quote them verbatim. After all five probes complete, emit a single-line summary: `HEALTH: OK` if every probe met its assertion, otherwise `HEALTH: DEGRADED — <comma-separated probe IDs that failed>`.

### Probe 1 — CONDUCTOR.md injection (the load-bearing one)

Invoke the SessionStart hook surface directly and capture both streams:

```bash
oj-helper conductor-inject 2>&1
```

Assertions:

- Exit code is `0`.
- Either stdout contains valid JSON with `.hookSpecificOutput.hookEventName == "SessionStart"` AND a non-empty `.hookSpecificOutput.additionalContext` (CONDUCTOR.md found and emitted), OR stderr contains the literal substring `OpenJunto: CONDUCTOR.md missing` (CONDUCTOR.md absent — degraded but expected when uninstalled).
- If `additionalContext` is non-empty, report its byte length (e.g., "additionalContext: 20146 bytes").
- If stderr has the missing-CONDUCTOR advisory, recommend the user verify `${CLAUDE_PLUGIN_ROOT}/CONDUCTOR.md` exists.

### Probe 2 — oj-helper on PATH + executable

```bash
command -v oj-helper && [ -x "$(command -v oj-helper)" ] && echo "oj-helper: $(command -v oj-helper)"
```

Assertions:

- Exit code is `0`.
- Output names a path that resolves and is executable.
- If exit code is non-zero, report "oj-helper not on PATH — plugin not installed or PATH is missing the plugin shim".

### Probe 3 — jq dependency

```bash
command -v jq && jq --version
```

Assertions:

- Exit code is `0`.
- jq version is reported. (`oj-helper conductor-inject` degrades gracefully without jq, but injection is silently skipped — adopter should know.)
- If exit code is non-zero, report "jq missing — CONDUCTOR injection will be skipped; install via `brew install jq` or equivalent".

### Probe 4 — plugin.json sanity

```bash
cat "${CLAUDE_PLUGIN_ROOT:-.}/.claude-plugin/plugin.json" | jq -r '.name'
```

Assertions:

- Output is exactly `oj`.
- If output is anything else (including empty / `null`), report `.claude-plugin/plugin.json` is corrupt or has a non-canonical `name`.

### Probe 5 — SubagentStart hook wires inject-profile

```bash
jq -r '.hooks.SubagentStart[]?.hooks[]?.command' "${CLAUDE_PLUGIN_ROOT:-.}/hooks/hooks.json" | grep -F 'oj-helper inject-profile'
```

Assertions:

- Exit code is `0` (grep found at least one matching line).
- The matched line is the SubagentStart entry that drives expert-profile injection. If absent, no expert profiles will reach spawned sub-agents.

## Reporting

After running every probe, write a brief report covering:

1. The literal command for each probe and its captured exit code + first line of stdout/stderr.
2. Per-probe verdict: PASS / FAIL / DEGRADED.
3. The single-line summary: `HEALTH: OK` or `HEALTH: DEGRADED — <ids>`.
4. If any probe FAILed, name one remediation step (most-likely-cause first). Examples:

   - Probe 1 emits `CONDUCTOR.md missing` → "Verify the plugin is installed at the expected root and CONDUCTOR.md is present. Try: `ls ${CLAUDE_PLUGIN_ROOT}/CONDUCTOR.md`."
   - Probe 2 fails → "Plugin not on PATH. Reinstall via `claude plugin install openjunto/oj-claude` and reopen the session."
   - Probe 3 fails → "Install jq: `brew install jq` (macOS) or `apt install jq` (Ubuntu)."
   - Probe 4 returns null → "`.claude-plugin/plugin.json` is corrupt. Re-extract or reinstall the plugin."
   - Probe 5 finds no match → "SubagentStart hook missing. Inspect `hooks/hooks.json` and verify the `oj-helper inject-profile` entry under `SubagentStart`."

## Notes for the LLM running this skill

This skill is **empirical**: do **not** substitute structural reasoning ("the file exists, therefore the hook works") for actual command execution. The whole point is to detect runtime breakage that a layout audit misses — for example, `oj-helper` present on disk but blocked by a missing `bin/lib/contracts.sh` (the helper dies at startup; structural-only checks would say "everything looks fine"). The literal subprocess invocations above are the contract; do not skip any of them.
