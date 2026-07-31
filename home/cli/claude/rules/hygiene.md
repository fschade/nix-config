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
  re-imports), say it loudly at the end. And if the repo keeps a place for
  manual steps, add it there.
- Evergreen names and comments: name things by what they do in the domain,
  never by their history: no `new`, `v2`, `improved`, `legacy` in identifiers,
  no comments about what changed (via harperreed/dotfiles, thanks).
- Fix root causes, not symptoms: no workaround patches, no retry band-aids.
  Work from the actual error, not a guess about it (via obra/dotfiles +
  harperreed/dotfiles, thanks).
- Deterministic work happens in scripts, not in your head: arithmetic, date
  math, data transforms, regex checks. Write and run the snippet instead of
  computing it in the reply (via jbarbier/CLAUDE.md, thanks).
- Snapshot before bulk data changes: dump what a migration or backfill will
  touch to a file first (via jbarbier/CLAUDE.md, thanks).
- Don't name a gitignored path from tracked code, docs or comments. A `tmp/`,
  a `dist/`, a `.direnv/` is scratch or build output, gone on a fresh checkout,
  so anything committed that points at one is a hidden coupling that breaks
  where the file isn't. Scratch output goes to scratch, but the tracked side
  never mentions where. The git dir (`.git/`) is not a gitignored path, it is
  always there, so it is a fine home for a tool's own scratch.
- One-way wall between AI config and the repo. AI-facing files (CLAUDE.md,
  AGENTS.md, `.claude/`, `.agents/`, rules, skills, agents, hooks, memory) may
  name each other and any repo file freely. Nothing repo-facing points back:
  no code, comment, doc, script, identifier, commit message or PR text
  references an AI file. A README never says "see CLAUDE.md", a comment never
  cites a rule file as its why, an ADR never quotes an agent instruction. When
  a why lives only in an AI file, restate it in place instead of pointing at
  it. This is separation, not secrecy: the AI files may sit visibly in the
  tree, the repo artifacts just never lean on them. Only where AI
  config is itself the subject (a repo that ships it, a commit that changes
  `.claude/`) is naming it payload, not bleed.
