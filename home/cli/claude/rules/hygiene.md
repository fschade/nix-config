# Everyday hygiene

- Docs follow code: when a change alters behavior that a README, MANUAL, or doc
  comment describes, update that doc in the same change. If code and docs
  contradict each other, say so instead of silently picking one.
- Comments rot: when editing code, fix or delete comments that no longer match.
  Never leave a comment describing the old behavior next to new code.
- No leftovers: no debug prints, console.log, commented-out code, or scratch
  files in the repo. Temp work belongs in the scratchpad, not the project.
- No stray TODOs: either do it now or surface it to me at the end of your reply
  — don't bury intentions in the code. Existing TODOs you touch: mention them.
- Don't swallow errors: no ignored error returns, no empty catch blocks. When
  ignoring one is genuinely right, the comment says why.
- If a change needs a manual step afterwards (approval dialogs, restarts,
  re-imports), say it loudly at the end — and if the repo keeps a place for
  manual steps (like MANUAL.md in nix-config), add it there.
- Evergreen names and comments: name things by what they do in the domain,
  never by their history — no `new`, `v2`, `improved`, `legacy` in identifiers,
  no comments about what changed (via harperreed/dotfiles, thanks).
- Fix root causes, not symptoms: no workaround patches, no retry band-aids.
  Work from the actual error, not a guess about it (via obra/dotfiles +
  harperreed/dotfiles, thanks).
- Deterministic work happens in scripts, not in your head: arithmetic, date
  math, data transforms, regex checks — write and run the snippet instead of
  computing it in the reply (via jbarbier/CLAUDE.md, thanks).
- Snapshot before bulk data changes: dump what a migration or backfill will
  touch to a file first (via jbarbier/CLAUDE.md, thanks).
