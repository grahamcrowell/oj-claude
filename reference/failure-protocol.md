# Failure Protocol

Sub-agent failure handling. When the Consult primitive (Task tool spawn) fails, this protocol structures the recovery path so the manager neither thrashes nor silently bypasses delegation.

> When the Consult primitive works (99% of spawns), this protocol is dead code. When it doesn't, it's the difference between a stuck session and a recovered one.

---

## 3-Step Protocol

### Step 1: Retry with Variations

Before declaring failure, attempt the spawn with these variations. Try each before moving on. Do not retry the exact same invocation more than once.

| # | Strategy | When to Try |
|---|----------|-------------|
| 1 | **Exact retry** | Transient network or scheduler hiccup. Try once. |
| 2 | **Alternate working directory** | Tool path or git context dependent on cwd. Cd to the project root or another known-good directory. |
| 3 | **Background mode** (`run_in_background: true`) | Spawn times out in foreground but the task is legitimately long. |
| 4 | **Simplified prompt** | Prompt may exceed the model's effective context. Strip auxiliary context, keep the core task. |
| 5 | **Bash subagent type** | Task is a shell-shaped operation; the Bash subagent is more reliable for one-shot commands. |

If all 5 variations fail, proceed to Step 2.

### Step 2: Document Failure Details

Record:

```
SPAWN FAILURE
  Profile attempted: [profile-filename]
  Subagent types tried: [list]
  Error message(s): [verbatim]
  Variations attempted: [list of strategies from Step 1]
  Last known good spawn (if any) in this session: [profile + timestamp]
```

This is not for the user yet. It is for the escalation message in Step 3 — and for the dev-mode feedback file if `OJ_DEVMODE=1`.

### Step 3: Escalate to User

Present the failure summary plus 4 options:

| Option | Description | When to Choose |
|--------|-------------|----------------|
| **Fix environment** | User repairs the underlying tool/config issue (e.g., missing API key, broken hook). Session pauses. | Failure is environmental and the user can address it. |
| **Supervised delegation** | Manager spawns again with the user watching; user accepts or rejects each output inline. | Trust is partial; the user wants oversight. |
| **Emergency direct execution** | Manager does ONE task directly, bypassing delegation. See protocol below. | Task is urgent and small; environment cannot be fixed in time. |
| **Abort** | Stop the engagement. Document what was attempted. | Task can wait, or the user prefers to debug offline. |

The user picks one. The manager does not silently choose.

---

## Emergency Direct Execution Protocol

When (and only when) the user selects "Emergency direct execution", the manager temporarily breaches the delegation boundary. This is exceptional and constrained:

1. **Announce clearly** before each action: *"Emergency direct execution: I am bypassing delegation to do X because [reason]. User-approved."*
2. **Attribute work** in the final deliverable: each direct-execution action is labeled in the handback so peer review can target it specifically.
3. **Retry each request** — spawn ONE more time before each direct action, in case the failure was transient. Do not assume the breach persists across actions.
4. **Time-box to 1 request** — emergency mode applies to a single user request. The next request restarts triage from scratch with no implicit continuation.
5. **Document in deliverables** — final response includes an "Emergency execution log" section listing every direct action and its rationale.

> Emergency direct execution exists to unblock urgent work, not to provide an escape hatch from peer review. The forcing functions (announce, attribute, time-box, document) make the breach visible and auditable.

---

## Recovery Checklist

Before each new user request after a failure event, verify:

- [ ] **Spawn primitive working** — issue one trivial test spawn (e.g., a 1-line analysis) and confirm it succeeds before triaging the next real request.
- [ ] **Emergency flag cleared** — emergency mode does not carry over. The new request starts in normal delegated mode.
- [ ] **Documentation updated** — if the failure has any persistent root cause (e.g., a profile that consistently fails to load), record it in the dev-mode feedback file and surface to the user.

If the test spawn fails again, return to Step 1 immediately. Do not begin the user's real request on a broken primitive.
