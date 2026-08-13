<!-- Hierarchy profile: open-questions.md (root node)
     Scope: unresolved questions blocking or shaping workspace-level work
     Resolve with: oj-helper resolve-path open-questions -->

# Open Questions

Questions that are genuinely open and that matter. Each one names who or what
would settle it, so it can be closed rather than accumulating.

An open question is not a task (that is the backlog) and not an unverified fact
(that is `facts/` with an `ASSERTED-UNVERIFIED` marker). The difference from a
fact is whether you have a candidate answer: if you do, record it as
`ASSERTED-UNVERIFIED` with its verification path; if you do not, it is a question.

**Closing a question is a real step.** When one is settled, move the answer to
where it belongs — `decisions.md` if it was a choice, `facts/` if it was a
measurement — and mark the entry here `resolved` with a link. A question list
that only grows stops being read, which is the same as not having one.

## Format

```markdown
## [Q-NNN] [The question, as a question]

**Status:** open | resolved [YYYY-MM-DD] -> [link to the decision or fact]
**Raised:** [YYYY-MM-DD]
**Blocking:** [what cannot proceed until this is answered, by backlog id -- or
"nothing yet, but it shapes [X]". Say which; an unblocking question and a
blocking one deserve different urgency.]

**Question.** [State it precisely enough that an answer would be recognizable
as one. "How should we handle caching?" is not answerable; "do we need
read-after-write consistency for [X]?" is.]

**What would settle it.** [The specific thing: a person who owns the call, a
measurement to take, a document to read, a prototype to run. A question with no
route to an answer is a note, not an open question -- say so if that is what it
is.]

**Current best guess.** [Optional. If there is one, say so and say how confident
-- it stops the question from being re-derived from scratch each time it comes
up. If the guess firms into something you would act on, it belongs in `facts/`
as `ASSERTED-UNVERIFIED` with its verification path.]
```

## Ids

`Q-NNN`, stable, never renumbered — they get cited from the backlog and from
design documents. Keep them unique across the whole workspace, for the same
reason backlog ids are unique across the file set: an id that names two things
makes every reference to it ambiguous.
