<!-- Hierarchy profile: [PROJECT_NODE]/decisions.md
     Resolve with: oj-helper resolve-path decisions --node [PROJECT_NODE] -->

# [PROJECT_NODE] -- Decisions

Choices that bind this node, newest first. A decision that binds the whole
workspace belongs in the root `../decisions.md` instead — file by the scope the
decision actually has, not by where the work happened to be done.

**This file accumulates.** Appending is the normal operation. A superseded
decision stays, marked, because the fact that it was once the answer is part of
why the current answer is what it is.

`design.md` summarizes these for a reader; this file is the authoritative record.
Keep the rationale here and link from there, so the two cannot drift.

## Format

```markdown
## [YYYY-MM-DD] [The decision, stated as what will happen]

**Status:** active | superseded by [link] | reversed [YYYY-MM-DD]
**Scope:** [PROJECT_NODE] [| and which subjects, if narrower]

**Decision.** [One or two sentences, stated as a commitment.]

**Why.** [The constraint that actually forced the answer -- that is what a
reader six months out needs, not the summary of the discussion.]

**Alternatives considered.** [What was rejected, and the specific reason.
An alternatives list without reasons is decoration, and it is what makes
someone re-open a settled question.]

**Reversal cost.** [What undoing this would take. Say so explicitly when it is a
one-way door -- that is the fact most likely to be forgotten.]
```

## Superseding

Set the old entry's `Status` to `superseded by [link]` and append the new one.
Never edit or delete a superseded decision: a log whose entries get rewritten
cannot answer "why did we do it that way", which is the only question it exists
to answer.
