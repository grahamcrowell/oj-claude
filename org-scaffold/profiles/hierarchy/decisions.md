<!-- Hierarchy profile: decisions.md (root node)
     Scope: decisions that bind the whole workspace
     Resolve with: oj-helper resolve-path decisions
     Node-local equivalent: oj-helper resolve-path decisions --node <relpath> -->

# Decisions

Choices that are made and are binding, newest first. This file is the root
node's decision log: decisions here bind the whole workspace. A decision that
binds only one node belongs in that node's own `decisions.md`.

**This file accumulates.** Appending is the normal operation, not an exception.
Do not rewrite history to make it read better — a superseded decision stays,
marked, because the fact that it was once the answer is part of why the current
answer is what it is.

## What belongs here

A decision, not a discussion. If it is still being weighed it belongs in
`open-questions.md`; move it here when it is settled. If it is a measurement
rather than a choice, it belongs in `facts/`.

## Format

```markdown
## [YYYY-MM-DD] [The decision, stated as what will happen]

**Status:** active | superseded by [link] | reversed [YYYY-MM-DD]
**Scope:** [what this binds -- the whole workspace, or which nodes]

**Decision.** [One or two sentences. State it as a commitment, not a preference.]

**Why.** [The reasoning that survives the meeting. Include the constraint that
actually forced the answer -- that is what a reader six months out needs.]

**Alternatives considered.** [What was rejected and the specific reason. An
alternatives list with no reasons is decoration; it is also what makes someone
re-open a settled question.]

**Reversal cost.** [What it would take to undo this. Name it explicitly when
this is a one-way door -- that is the fact most likely to be forgotten.]
```

## Superseding

Do not delete or edit a superseded decision. Set its `Status` to
`superseded by [link]` and append the new one. A decision log whose entries get
rewritten cannot answer "why did we do it that way", which is the only question
it exists to answer.
