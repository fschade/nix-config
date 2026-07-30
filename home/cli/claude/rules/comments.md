# Code comments

The voice: short, plain, everyday English, slightly informal. It should sound
like the person who wrote the code, a german native speaker, not like polished
output. Small natural slips are fine and wanted: missing articles, loose verb
agreement, e.g. "lefthook call it per repo", "diff that understand syntax".
Readable, not broken. Lowercase start, no trailing period on fragments. Comment
only where the code can't speak for itself.

No long parenthetical rationale. No comma chains either. Two statements are two
sentences. Where a comma joins them a period does it better.

- Why, not what. The code already says what it does; the comment says why it
  has to be this way, which trap it avoids, or which obvious alternative
  doesn't work. Name the command to run or the file that holds the other half
  when that is the answer.
- Describe the state, don't tell a story. Say what is true now, in one go.
  No "we first tried X, then Y", no build-up, no narrative arc. Factual and to
  the point.
- No history the code no longer has. Even an accurate comment about a removed
  implementation, an old flag, a previous approach or a past bug is dead
  weight: delete it together with the thing it described. Complements the
  comment-rot rule in hygiene.md, which covers comments that went stale.
- No restatement. If the comment repeats the line under it, drop the comment.

  ```python
  # bad, says what the line says
  # retry three times
  for attempt in range(3):

  # good, says why the number is three
  # the upstream rate limit resets after 30s, three attempts with the
  # backoff below covers one window without hammering it.
  for attempt in range(3):
  ```

- No AI boilerplate. Skip "This function is responsible for ...", "Note that
  it is important to ...", hedging, and complete-sentence polish.

  ```bash
  # bad
  # Note that this guard is responsible for validating the command string prior
  # to execution. It is important to ensure that wrapped invocations are also
  # matched by the pattern.

  # good
  # rm is matched as a word, not anchored on a separator: an anchor misses
  # everything with something in front, sudo rm, sh -c "rm ...", xargs,
  # find -exec
  ```

- One block per unit, not one per line. A short paragraph at the head of a
  function, derivation or rule block beats a comment on every line inside it.
