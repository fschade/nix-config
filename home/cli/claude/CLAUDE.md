# Global instructions

These apply in every project. Project-level CLAUDE.md files add to or override
this.

## Communication

- Mirror my language: reply in German when I write German, in English when I
  write English. Code, comments, commit messages, and docs are always English.
- Be direct and concise. Lead with the result, then the reasoning. No filler, no
  cheerleading.

## Working style

- Small, clearly scoped tasks: just do them. Larger changes (refactors, new
  modules, anything touching many files): sketch the approach in a few lines
  first and get my OK before writing code.
- Verify work before calling it done: run the project's formatter/linter/tests
  when they exist. Look for mise tasks (mise.toml) first, then Makefile /
  package.json scripts / flake checks.
- Prefer the smallest diff that solves the problem. No drive-by refactors, no
  speculative abstractions, no over-engineering.
- Don't create documentation files (README, docs/) unless I ask for them.
- No new dependencies without asking. And no hand-rolling what an existing
  dependency already does (via jbarbier/CLAUDE.md, thanks).
- Stop and ask when: several valid approaches with real consequences, deleting
  or restructuring existing code, anything security-related, or a genuine
  comprehension gap (via obra/dotfiles + harperreed/dotfiles, thanks).
- Auto memory is a scratch pad, not an archive. It is machine-local and in no
  repo, so nothing a second machine would need may live only there. Once a note
  turns out to be durable, put it where it belongs and delete the memory: a rule
  for every project into this file or `rules/`, a convention of one project into
  that project's CLAUDE.md, something about this machine into MANUAL.md. What
  stays in memory is what only the current thread needs.

## Code style

- Match the surrounding code: naming, idioms, formatting, comment density.
- Comments: voice, failure modes and examples are in `rules/comments.md`.
- Three dots, not the ellipsis character: write `...` everywhere, no exception.
  I hate `…`. macOS menu labels included, the HIG wants the single glyph there
  and it does not get it ("Settings...").
- No `—` and no arrow or bullet glyphs (`→` `·` `⇒`) in anything you write:
  code, comments, docs, commit messages, replies. A plain `-` is fine, so is
  splitting the clause into its own sentence. Only where a glyph is the payload
  does it stay (icon maps, UI labels).
- Replace, don't deprecate: when replacing an implementation, remove the old
  one: no compat shims, no dual code paths, unless I ask for a migration.
- Never invent technical details: versions, env vars, API endpoints, config
  keys, CLI flags. Look them up or say you don't know (via harperreed/dotfiles,
  thanks).

## Git & deployment

- NEVER push. Not on request completion, not "to wrap up", not ever. I always do
  that myself (the deny rule catches the plain form, bash-guard the rest).
- Committing is fine, also on your own initiative, but only completed, coherent
  units (checks/tests green), and ALWAYS list what you committed (short hash +
  message) at the end of your reply so I keep the overview. Never commit
  half-working state.
- Never amend, rebase, or reset commits you did not create in this session.
- Deploy commands (`darwin-rebuild`, `mise run deploy`,
  `terraform`/`tofu apply`, `kubectl apply`, and anything comparable) never on
  your own initiative. Run one only when I explicitly ask for it. Some repos
  whitelist deploys via project permissions. That only skips the prompt, it does
  not change the "only when asked" part.
- Staging as part of your own commit is normal, but name the paths. `git add -A`
  or a bare `.` takes whatever else sits in the tree with it, up to another
  session's half-finished work, and the commit stops being what its message
  says. Standalone `git add` (without committing) only when a tool genuinely
  needs it (nix flakes only see tracked files). Say so when you did.
- Commit messages: conventional commits (`feat:`, `fix:`, `chore:`, `docs:`,
  `refactor:`, `test:`), lowercase, terse, no trailing period. Only exception:
  repos with a clearly different established convention (e.g. nixpkgs'
  `pkg: 1.2 -> 1.3`), then follow theirs.
- NEVER add Co-Authored-By, "Generated with", or any other Claude/AI attribution
  to commits or PRs. No trailers, no footers. The message ends with its content.
- Commit messages and PR text in plain, factual language. A bug fix is a bug
  fix, not a "critical stability improvement". Avoid: critical, crucial,
  essential, significant, comprehensive, robust, elegant.
- Never rewrite history on shared branches.

## Environment

- Main machine: Mac Studio (Apple Silicon, macOS), managed declaratively via
  nix-darwin + home-manager (`~/Developer/fschade/nix-config`).
- This global claude config is versioned in nix-config (`home/cli/claude/`) and
  is the golden rule: never edit `~/.claude/settings.json` or
  `~/.claude/CLAUDE.md` directly. Change the repo copies and tell me to deploy.
  Project-specific permission extensions go into the project's own
  `.claude/settings.json` / `.claude/settings.local.json`.
- Global skills and subagents are declared in `home/cli/claude/default.nix`
  (pinned flake inputs). Every config surface is a read-only store path:
  `~/.claude/skills`, `~/.claude/agents`, `~/.claude/commands`,
  `~/.claude/plugins`, `~/.agents`. So no `npx skills add -g`, no
  `claude plugin install`: to add something, declare it there and tell me to
  deploy. Language servers go into settings.json under `lspServers`, not via a
  plugin. Project-scoped skills and agents (`<repo>/.claude/skills`,
  `<repo>/.claude/agents`, `<repo>/.agents/skills`) are yours to install as you
  like.
- Preferred task runner: mise (`mise run <task>`). Check mise.toml for how to
  build/test/deploy before inventing commands.
- Homelab: Proxmox hosts + Kubernetes, config in `~/Developer/fschade/homelab`.
