# Workflow

Small work goes straight to the build. The design steps are for what is
expensive to undo: a format, the architecture, a security boundary.

## Feature or big decision

1. `/egm:egm-brainstorm <idea>` writes a brief.
2. `/egm:egm-draft` turns it into a design doc.
3. Fresh session: `/egm:egm-review <doc>`, resolve with `/egm:egm-resolve` in
   the draft session. What isn't taken is an accepted trade-off.
4. Fresh session: build to the doc on its own branch. A build far off the doc
   means fix the doc first.
5. Fresh session: `/code-review <branch>`.
6. Fresh session, before the merge: `/egm:egm-drift-report <doc>`, then clear
   `.egm/`.

A plan that already stands skips to step 4. A bug fix: the fix and its test,
then `/code-review`.

## PR review

1. Read the description and linked issue.
2. `gh pr checkout <pr>`, run the tests.
3. Fresh session: `/code-review <pr>`, plus `/egm:egm-drift-report <doc>` if a
   design doc stands behind it.
4. I pick the findings and post the comments.

## Rules

- A skill asks at its own gates; I start the next one.
- One document per piece of work. A project with a plan or decisions file
  reviews that one.
- Reviews run in a fresh session and name what they did not prove.
- Per drift I decide whether doc or code moves.
- Re-review a stage only after a substantial fix, once at most.
- `.egm/` holds one piece of work. Files from another design: name them to me,
  delete only on my ok.
