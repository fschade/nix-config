# Global instructions

These apply in every project. Project-level CLAUDE.md files add to or override
this.

## Communication

- Mirror my language: detect the language I write in and reply in it, whatever
  it is. Code, comments, commit messages and docs stay English regardless.
- Be direct and concise. Lead with the result, then the reasoning. No filler, no
  cheerleading.
- State, not history. Say what is true now, not how it got there: no "first X,
  then Y", no account of the attempts before the one that worked, in replies,
  docs and commit messages alike. The path only goes in when I need it to decide
  something, and then in a sentence. Same rule for code lives in
  `rules/comments.md` and the evergreen-names point in `rules/hygiene.md`.

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
  for every project into `home/cli/claude/CLAUDE.md` or `home/cli/claude/rules/`
  in nix-config (never the deployed `~/.claude` copy, a switch overwrites it), a
  convention of one project into that project's CLAUDE.md, something about this
  machine into nix-config's MANUAL.md. What stays in memory is what only the
  current thread needs.

## Code style

- Match the surrounding code: naming, idioms, formatting, comment density. This
  holds across sessions, not just within a file: read what is already there and
  write like it, so the repo reads as one hand, not a stack of visiting styles.
  Where a repo has an established style, it wins over any default, including the
  comment voice in `rules/comments.md`.
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
  thanks). Where to look and what to do when it isn't findable:
  `rules/research.md`.

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
- Default to subject only. A body only for a why the diff doesn't show, then one
  or two lines. No listing the what per file, the diff already does that. No
  novels.
- NEVER add Co-Authored-By, "Generated with", or any other Claude/AI attribution
  to commits or PRs. No trailers, no footers. The message ends with its content.
- Commit messages and PR text in plain, factual language, same voice as
  `rules/comments.md`: a human reads it and gets it, not wades through it. A bug
  fix is a bug fix, not a "critical stability improvement". Avoid the inflated
  words: critical, crucial, essential, significant, comprehensive, robust,
  elegant.
- Never rewrite history on shared branches.

## Nothing goes outward

- Nothing you do ever posts in my name. No PR, no issue, no comment, no review,
  no release, no published package, no mail, no forum or social post, nowhere,
  never. Not on your own initiative and not on request: I send those myself,
  same as pushing. Don't look for the way around it either, not through the api,
  not through a wrapper, not through the browser. When something genuinely has
  to go out, say so in your reply and leave it to me.
- Drafting is fine and is the whole job here: the PR text, the issue body, the
  release notes, the mail, into a file or into your reply. Sending is mine.
- Local dev is not outward: http writes to localhost, 127.x, ::1,
  host.docker.internal or a `.test` / `.localhost` host are api testing and
  stay open. A project widens that with `.claude/outbound-hosts` at its root,
  one host per line; I put hosts there, you don't. Triggering my own CI
  (`gh workflow run`, `gh run rerun`) counts as local too.
- The shell side is guarded (`hooks/bash-guard.sh`), the browser side cannot be:
  the Chrome tools only see a tab id, so no hook can tell whether a click lands
  on localhost or on github.com. There you read, navigate, screenshot and check
  the console. Typing into a page and submitting it is local dev only
  (localhost, 127.0.0.1, a `*.test` host). On anything public you submit no
  form, post no comment and confirm no dialog that writes.

## Environment

- Main machine: Mac Studio (Apple Silicon, macOS), managed declaratively via
  nix-darwin + home-manager (`~/Developer/fschade/nix-config`).
- This global claude config is versioned in nix-config (`home/cli/claude/`) and
  is the golden rule: never edit `~/.claude/settings.json` or
  `~/.claude/CLAUDE.md` directly. Change the repo copies and tell me to deploy.
  Project-specific permission extensions go into the project's own
  `.claude/settings.json` / `.claude/settings.local.json`.
- Global skills and subagents are declared in nix-config
  (`home/cli/claude/default.nix`, pinned flake inputs). Every config surface is
  a read-only store path: `~/.claude/skills`, `~/.claude/agents`,
  `~/.claude/commands`, `~/.claude/plugins`, `~/.agents`. So no
  `npx skills add -g`, no `claude plugin install`: to add something, declare it
  there and tell me to deploy. Language servers go into settings.json under
  `lspServers`, not via a plugin. Project-scoped skills and agents
  (`<repo>/.claude/skills`, `<repo>/.claude/agents`, `<repo>/.agents/skills`)
  are yours to install as you like.
- Preferred task runner: mise (`mise run <task>`). Check mise.toml for how to
  build/test/deploy before inventing commands.
