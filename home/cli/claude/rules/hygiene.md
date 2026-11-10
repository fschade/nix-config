# Everyday hygiene

- Docs follow code in the same change. Code and docs disagree: say so, don't
  pick one silently.
- Fix or delete comments the change made wrong.
- No leftovers: debug prints, commented-out code, scratch files.
- No new TODOs: do it now or name it at the end of the reply. Mention existing
  ones you touch.
- No swallowed errors. Ignoring one on purpose gets a comment saying why.
- A manual step the change creates also goes where the repo keeps them.
- Name things by what they do, never by history: no `new`, `v2`, `legacy`.
- Fix root causes, no workarounds, no retry band-aids.
- Arithmetic, dates, transforms, regex: run a snippet, don't compute in the
  reply.
- Before a bulk data change, dump what it touches to a file.
- Tracked files never name a gitignored path (`tmp/`, `dist/`, `.direnv/`): it
  is gone on a fresh checkout. `.git/` is fine for a tool's scratch.
- AI config (CLAUDE.md, AGENTS.md, `.claude/`, `.agents/`, rules, skills,
  hooks, memory) may name anything; nothing repo-facing points back at it.
  Restate the why in place. Exception: AI config is the subject.
