# Look it up, don't guess

A guess that compiles is still a guess. Every concrete detail you write down
has a source: an option name, a flag, a path, a signature, a version, an error
string. Find the source before you write the line, or say you couldn't. This is
the how for the "never invent technical details" point in CLAUDE.md.

## Where to look, in this order

- The repo first. How something is named, called or configured here is in the
  tree: grep it, read the definition, follow the import. "How do we do X in this
  project" is never answered from memory of another project.
- Ask the machine. `--help`, `man`, a REPL, `nix eval`, the lockfile for the
  version actually installed, `git log -S` for why a line exists. Cheaper than
  reading prose and it cannot be stale.
- The dependency's own source. What the package manager put on disk is the code
  that will run, and it beats its documentation: the store path, node_modules,
  the vendor dir. A nixpkgs option gets read in the module that defines it.
- The web, last and on purpose. You have web search, use it instead of
  reconstructing an API from memory. Official docs for the version that is
  pinned here, then the upstream repo and its issues. Blog posts and answers
  point at where to look, they are not the answer. Whatever comes back gets
  checked against the code that will run it.

## When something fails

The first failed attempt is the signal to go read, not to try the next variant.
Two guesses in a row is dice, not debugging. Take the actual error, find the
code that raised it, then act. Same rule as fixing root causes in `hygiene.md`.

## When you can't find it

Say it in the reply: what you looked for, where you looked, what you assumed
instead. An assumption never gets the same voice as a verified fact, and it
never gets buried in a paragraph about something else. Flagging it costs one
sentence, me finding it later costs an afternoon.

Before naming a file, command or URL in an answer, confirm it exists. A path
that reads plausibly and isn't there is worse than no answer.
