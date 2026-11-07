# Everyday hygiene

- Docs follow code: when a change alters behavior that a README, MANUAL, or doc
  comment describes, update that doc in the same change. If code and docs
  contradict each other, say so instead of silently picking one.
- Comments rot: when editing code, fix or delete comments that no longer match.
  Never leave a comment describing the old behavior next to new code.
- No leftovers: no debug prints, console.log, commented-out code, or scratch
  files in the repo. Temp work belongs in the scratchpad, not the project.
- No stray TODOs: either do it now or surface it to me at the end of your reply.
  Don't bury intentions in the code. Existing TODOs you touch: mention them.
- Don't swallow errors: no ignored error returns, no empty catch blocks. When
  ignoring one is genuinely right, the comment says why.
- If a change needs a manual step afterwards (approval dialogs, restarts,
  re-imports), it goes under **Your turn** (CLAUDE.md). And if the repo keeps a
  place for manual steps, add it there.
- Evergreen names and comments: name things by what they do in the domain,
  never by their history: no `new`, `v2`, `improved`, `legacy` in identifiers,
  no comments about what changed.
- Fix root causes, not symptoms: no workaround patches, no retry band-aids.
  Work from the actual error, not a guess about it.
- Deterministic work happens in scripts, not in your head: arithmetic, date
  math, data transforms, regex checks. Write and run the snippet instead of
  computing it in the reply.
- Snapshot before bulk data changes: dump what a migration or backfill will
  touch to a file first.
- Don't name a gitignored path from tracked code, docs or comments. A `tmp/`,
  a `dist/`, a `.direnv/` is scratch or build output, gone on a fresh checkout,
  so anything committed that points at one is a hidden coupling that breaks
  where the file isn't. Scratch output goes to scratch, but the tracked side
  never mentions where. The git dir (`.git/`) is not a gitignored path, it is
  always there, so it is a fine home for a tool's own scratch. The data side
  is stricter still: gitignored contents are a vault, `data-privacy.md`.
- One-way wall between AI config and the repo. AI-facing files (CLAUDE.md,
  AGENTS.md, `.claude/`, `.agents/`, rules, skills, agents, hooks, memory) may
  name anything. Nothing repo-facing (code, comment, doc, script, identifier,
  commit message, PR text) points back at them; when a why lives only in an AI
  file, restate it in place. Exception: AI config is itself the subject (a repo
  that ships it, a commit that changes `.claude/`).
