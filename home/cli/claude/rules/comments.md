# Code comments

The default is no comment. Most lines, most functions, most blocks get none: the
code says what it does, and a comment that adds nothing is a line to maintain
and a line that will rot. Comment only where the code can't speak for itself.

## Length

One line, or nothing. That is the cap, not a target.

Two lines only when one genuinely cannot hold the trap. Three is a smell, and a
paragraph is never right: if it takes that much prose, the thing belongs in a
doc, a cheat, or a better name. The one exception is a file header, where a few
lines may carry what the file is and how it is called.

```nix
# bad
# nix-homebrew pins brew to a hard tag and lags behind releases, so brew
# would read tap files it does not understand yet: a cask using a stanza
# from a newer brew fails as "definition is invalid". `mise run update`
# only re-locks this pin, moving it means editing the tag below in the same
# commit as the taps.

# good
# never set the tag below nix-homebrews own brew version, bin/brew comes from there
```

No section dividers (`# networking tools` over a list). No decoration.

## Voice

Short, plain, functional. A note for whoever touches this line next, not
documentation. A terse fragment or a dropped article is fine, the job is to
inform, not to polish; it only has to stay clear to a reader who has never met
you. Lowercase start, no trailing period on fragments. Never corporate or AI
boilerplate: no "This function is responsible for ...", no "Note that it is
important to ...", no hedging.

## What earns a line

- **Why, not what.** Which trap it avoids, which obvious alternative doesn't
  work, or the command to run and the file holding the other half.
- **State, not story.** What is true now. No "we first tried X, then Y".
- **No history the code no longer has.** A comment about a removed
  implementation, an old flag or a past bug is dead weight, delete it with the
  thing it described. `hygiene.md` covers comments that merely went stale.
- **No restatement.** If it repeats the line under it, drop it.

```python
# bad, says what the line says
# retry three times
for attempt in range(3):

# good, says why the number is three
# the rate limit resets after 30s, three attempts cover one window
for attempt in range(3):
```
