# Global instructions

These apply in every project. A project's CLAUDE.md adds to or overrides this,
except the hard limits, which nothing overrides.

## Hard limits

Three lines, everything else in this section is detail:

- **Nothing leaves this machine in my name.** No push, no PR, no issue, no
  comment, no review, no release, no published package, no mail, no post.
  Not on your own initiative, not on request, not through the api, a wrapper
  or the browser. Drafting is the whole job: the PR text, the release notes,
  the mail, into a file or your reply. Sending is mine.
- **No shell on another machine.** No ssh, scp, sftp, ftp, no rsync to a
  remote host. What runs there is invisible to every guard here, and prod is
  what sits on the other end. Open only: hosts in the project's
  `.claude/ssh-hosts` (I put them there, you don't), each call still asks.
  Plain form only, the host as listed and directly after `ssh`:
  `ssh host -p 22 cmd`, `scp ... host:path`, no redirect, `cd` or `$(...)`.
- **Deploys only when I ask.** `darwin-rebuild`, `mise run deploy`,
  `terraform`/`tofu apply`, `kubectl apply`, anything comparable. bash-guard
  asks before each one it knows, a repo whitelisting a deploy cannot skip
  that, and the guard asking is no licence for one I did not ask for.

The detail:

- Local dev is not outward: http writes to localhost, 127.x, ::1,
  host.docker.internal or a `.test` / `.localhost` host are api testing and
  stay open. A project widens that with `.claude/outbound-hosts` at its root,
  and I confirm its hosts when the session starts. A confirmed host opens for
  the whole session, the sandbox does not ask per call, and the first hard limit
  still holds there. Triggering my own CI (`gh workflow run`, `gh run rerun`)
  counts as local too.
- The shell runs in the claude code sandbox: writes stay in the project, network
  only to the listed hosts, the credential stores, `.env` files and private keys
  are out of reach. When something fails against that boundary, say so and leave
  it to me with `!`: deploys, docker, the nix daemon, git over ssh remotes,
  anything reading a real `.env`. Never try to route around it. WebFetch runs
  outside it and asks for every host not in `hooks/webfetch-guard.sh`.
- Secrets live in `.env`, nothing else does: `.envrc` is tooling and readable,
  urls, ports and flags go in a tracked file or `mise.local.toml`. A key that
  tests need is an agent key of its own with a spending limit, handed in
  through the session env (`.env.agent`, see nix-config's MANUAL.md). You can see it with
  `env`, so it never goes into output, a file or a commit.
- The shell side is enforced by the sandbox, cc-safety-net and `hooks/bash-guard.sh`, the
  browser side cannot be: the Chrome tools only see a tab id. There you read,
  navigate, screenshot and check the console. Typing into a page and submitting
  it is local dev only (localhost, 127.0.0.1, a `*.test` host) or a host listed
  in the project's `.claude/outbound-hosts`, matched against the tab's host, exactly
  or as a subdomain of a `*.domain` line.
  On anything else public you submit no form, post no comment and confirm no
  dialog that writes.

## Communication

- Reply in the language I write in, whatever it is. Code, comments, commit
  messages and docs stay English regardless.
- Lead with the result, then the reasoning. No filler, no cheerleading.
- State, not history. Say what is true now, not how it got there: no "first X,
  then Y", no account of the attempts before the one that worked, in replies,
  docs and commit messages alike. The path only goes in when I need it to
  decide something, and then in a sentence.
- What is mine to do goes last, under **Your turn**: numbered steps, each with
  the exact command in a code block (`! cmd` when it can run in this session)
  and what I should see after. No "you may want to", no "consider", no step
  buried mid-paragraph. Nothing for me to do, no section.

## Working

- Small, clearly scoped tasks: just do them. Larger changes (refactors, new
  modules, anything touching many files): sketch the approach in a few lines
  first and get my OK before writing code.
- Subagents default to sonnet, fine for search and research. One that writes
  code gets `model: "opus"` on the Agent call. Either way its report is a
  claim: read the diff and run the checks yourself before calling it done.
- You work only in the project you were started in. Anything outside it, ask
  first.
- Prefer the smallest diff that solves the problem. No drive-by refactors, no
  speculative abstractions, no over-engineering.
- Verify work before calling it done: run the project's formatter, linter and
  tests when they exist. Look for mise tasks (mise.toml) first, then Makefile /
  package.json scripts / flake checks.
- Stop and ask when: several valid approaches with real consequences, deleting
  data or files the change is not about, anything that changes a security
  boundary (sandbox, hooks, permissions, secrets), or a genuine comprehension
  gap. Ask once, your recommendation first.
- No new dependencies without asking. And no hand-rolling what an existing
  dependency already does.
- Docs and ADRs don't need asking for, but keep them lean: the shortest thing
  that answers the question, no prose around it. Extend the doc that already
  covers the topic instead of putting a second one beside it. Same cap as
  comments, see `rules/comments.md`.
- Skills supply workflows and criteria, never conventions. Where a skill's
  git, commit, doc or reporting habits differ from this file, this file wins.
- Never invent technical details: versions, env vars, API endpoints, config
  keys, CLI flags. Look them up or say you don't know. Where to look and what
  to do when it isn't findable: `rules/research.md`.
- Auto memory is a scratch pad, not an archive. It is machine-local and in no
  repo, so nothing another machine would need may live only there. Once a note
  turns out to be durable, put it where it belongs and delete the memory: a
  rule for every project into `home/cli/claude/` in nix-config (never the
  deployed `~/.claude` copy, a switch overwrites it), a convention of one
  project into that project's CLAUDE.md, a machine quirk into nix-config's
  MANUAL.md. What stays in memory is what only the current thread needs.

## Code style

- Match the surrounding code: naming, idioms, formatting, comment density.
  This holds across sessions, not just within a file: read what is already
  there and write like it, so the repo reads as one hand, not a stack of
  visiting styles. An established repo style wins over any default, including
  the comment voice in `rules/comments.md`.
- Comments: voice, failure modes and examples are in `rules/comments.md`.
- Three dots, not the ellipsis character: write `...` everywhere, no
  exception. I hate `…`. macOS menu labels included ("Settings...").
- No `—` and no arrow or bullet glyphs (`→` `·` `⇒`) in anything you write:
  code, comments, docs, commit messages, replies. A plain `-` is fine, so is
  splitting the clause into its own sentence. Only where a glyph is the
  payload does it stay (icon maps, UI labels).
- Replace, don't deprecate: when replacing an implementation, remove the old
  one. No compat shims, no dual code paths, unless I ask for a migration.

## Git

- Committing is fine, also on your own initiative, but only completed,
  coherent units (checks/tests green), and ALWAYS list what you committed
  (short hash + message) at the end of your reply. Never commit half-working
  state.
- Never amend, rebase, or reset commits you did not create in this session,
  and never rewrite history on shared branches.
- Your worktrees live in `<repo>/.claude/worktrees/<name>`, on their own branch,
  and go away after the merge. Never in a temp dir or next to the repo: next to
  the repo is where mine land, through `wt`.
- Stage by naming paths. `git add -A` or a bare `.` takes whatever else sits
  in the tree with it, and the commit stops being what its message says.
  Standalone `git add` only when a tool genuinely needs it (nix flakes only
  see tracked files); say so when you did.
- Commit messages: conventional commits (`feat:`, `fix:`, `chore:`, `docs:`,
  `refactor:`, `test:`), lowercase, terse, no trailing period. Subject only by
  default; a body only for a why the diff doesn't show, then one or two lines.
  Repos with a clearly different established convention (nixpkgs'
  `pkg: 1.2 -> 1.3`) win.
- NEVER add Co-Authored-By, "Generated with", or any other AI attribution to
  commits or PRs. No trailers, no footers.
- Commit messages and PR text in plain, factual language: a bug fix is a bug
  fix, not a "critical stability improvement". Avoid the inflated words:
  critical, crucial, essential, significant, comprehensive, robust, elegant.

## Environment

- Several machines run this same setup out of one repo (nix-config): macOS via
  nix-darwin + home-manager, linux via home-manager alone. Don't assume which
  machine you are on; run `hostname` when it matters.
- This global claude config is versioned in nix-config (`home/cli/claude/`)
  and that repo is the only source of truth: never edit `~/.claude/settings.json`
  or `~/.claude/CLAUDE.md` directly, a switch overwrites them. Change the repo
  copies and tell me to deploy.
- No global skills, agents, commands or plugins, by choice: those dirs are
  read-only, so no `npx skills add -g`, no `claude plugin install`. If one is
  genuinely needed, propose it in `home/cli/claude/default.nix`. Unwanted
  bundled skills are `off` in settings.json `skillOverrides`, language servers
  go under `lspServers`. Project skills and agents (`<repo>/.claude/skills`,
  `<repo>/.agents/skills`) are yours to install.
- EGM artifact directory: .egm
  The path is relative to the working directory, so egm starts from the repo
  root. `.egm/` is in the global gitignore.
- Preferred task runner: mise (`mise run <task>`). Check mise.toml for how to
  build/test/deploy before inventing commands.
