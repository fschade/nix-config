# Workflow

From an idea to merged code, and how big each step should be. Small work
skips straight to the build; the design steps are for what is expensive to
undo. Lost in a session: ask "what is the next step?".

## A feature or a big decision

A format, the architecture, a security boundary.

1. `/egm:egm-brainstorm <idea>` thinks the idea through and writes a brief.
2. `/egm:egm-draft` turns the brief into a design document.
3. Fresh session: `/egm:egm-review <doc>`. Take the findings that count, the
   rest is an accepted trade-off. Stages 7 and 9 offer "Resolve findings with
   agent"; for the other stages, take the findings to the draft session and
   run `/egm:egm-resolve` there, then re-run the review.
4. Fresh session: build to the doc on its own branch. The egm skills only
   write designs, so the build always runs outside them. Small commits, checks
   green. A small miss gets a point fix; a build wildly off means fix the doc
   and build again.
5. Fresh session: `/code-review <branch>`, the bare form only sees what is
   not pushed yet.
6. Fresh session: `/egm:egm-drift-report <doc>`, then clear `.egm/`.

## Work by a plan that stands

1. Build to the plan on its own branch, small commits, checks green.
2. Fresh session: `/code-review <branch>`.
3. Fresh session: `/egm:egm-drift-report <plan>`.

## A bug fix

1. The fix with the test that would have caught it.
2. Fresh session: `/code-review`.

## A PR review

1. Read its intent: description, linked issue.
2. Check it out (`gh pr checkout <pr>`), run the tests.
3. Fresh session: `/code-review <pr>`.
4. If a design doc stands behind it: `/egm:egm-drift-report <doc>`.
5. I decide which findings count. Review comments are drafts, I post them.

## Rules

- A skill asks at each of its own gates; the next one I start myself.
- One document per piece of work. A project that already keeps a plan or
  decisions file reviews that instead of drafting a second document, or the
  two drift apart.
- Check in a fresh session, so the reviewer does not share the author's
  context.
- Reviews always find something. Re-audit a stage only when a fix changed
  substance (a blocker, a major, a rewritten concept), never for nits; one
  re-audit per stage is the cap.
- `.egm/` is scratch for one piece of work. Before a brainstorm or draft, check
  it: files from another design get named to me, deleted only on my ok. When
  the work ends (drift report done, design dropped), delete its files one by
  one, then `rmdir` its folders deepest first; cc-safety-net blocks `rm -r`.
