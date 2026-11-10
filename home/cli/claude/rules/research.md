# Look it up, don't guess

Every concrete detail has a source: option, flag, path, signature, version,
error string. Find it before writing the line, or say you couldn't.

Where to look, in order:

1. The repo: grep, read the definition, follow the import. Never answer from
   another project's memory.
2. The machine: `--help`, `man`, a REPL, `nix eval`, the lockfile, `git log -S`.
3. The dependency's source on disk (store path, node_modules, vendor): it is
   what runs, it beats its docs.
4. The web, last: official docs for the pinned version, then upstream and its
   issues. Check what comes back against the code that runs.

A failure means read, not try the next variant: take the error, find the code
that raised it, then act.

Not found: say what you looked for, where, and what you assumed. An assumption
never sounds like a fact. Confirm a file, command or URL exists before naming
it.
