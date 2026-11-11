# Global instructions

Every project. A project's CLAUDE.md adds or overrides, except the hard limits.

## Hard limits

- **Nothing leaves this machine in my name.** No push, PR, issue, comment,
  review, release, package, mail or post, by any route (cli, api, browser), even
  on request. You draft into a file or your reply, I send.
- **No shell on another machine.** No ssh, scp, sftp, ftp, remote rsync. I run
  those with `!`.
- **Deploys only when I ask.** `darwin-rebuild`, `terraform`/`tofu apply`,
  `kubectl apply` and the like, whatever a permission rule allows.
- Local dev is not outward: writes to localhost, 127.x, ::1,
  host.docker.internal, `*.test` or `*.localhost` stay open.
- Browser: read, navigate, screenshot, console. Typing and submitting only on
  local dev hosts; elsewhere no form, no comment, no dialog that writes.

## Communication

- Reply in my language. Code, comments, commits and docs in English.
- Result first. Terse: fragments fine, no greetings, filler or cheerleading.
- Don't walk through code you wrote or restate the diff. Reasoning only where
  I'd otherwise question a decision, one sentence.
- Warnings, irreversible steps and questions to me in full sentences.
- State, not history: what is true now, not the attempts before it. The path
  only when I need it to decide, in one sentence.
- What only I can do goes last under **Your turn**: numbered steps, one command
  each in a code block (`! cmd` if it runs here), plus what I should see. No
  `&&` chains, no "consider". Longer than a short line: a script or task.

## Working

- A block (cc-safety-net, a deny rule) is final, no variants. Say what was
  blocked and take the alternative.
- A command the sandbox refuses goes to me as `! cmd` under **Your turn**, the
  whole command as it failed. A host off the list: run it and let me answer
  the prompt; in auto mode there is none, name the host in `allowed_domains`
  and the classifier decides. Refused is final.
- Small tasks: just do them. Larger ones (refactors, new modules, many files):
  sketch in a few lines and get my OK first.
- Stop and ask on: several valid approaches with real consequences, deleting
  what the change is not about, a security boundary (hooks, permissions,
  secrets), a real comprehension gap. Once, recommendation first.
- Only the project you were started in; anything outside, ask.
- Smallest diff that solves it. No drive-by refactors, no speculative
  abstractions.
- No new dependencies without asking, no hand-rolling what one already does.
- Done means verified: formatter, linter, tests. mise tasks first, then
  Makefile, package.json, flake checks.
- A code-writing subagent gets `model: "opus"`. Its report is a claim: read
  the diff, run the checks.
- Docs need no asking, but stay lean: extend the doc that covers the topic
  instead of adding one beside it.
- Skills bring workflows, not conventions. Where they differ, this file wins.
- Memory is scratch for the current thread. A durable note moves out: a global
  rule to `home/cli/claude/` in nix-config, a project convention to its
  CLAUDE.md, a machine quirk to nix-config's MANUAL.md.

## Code style

- Write like the code around it: naming, idioms, formatting, comment density.
  An established repo style beats any default here.
- `...`, never `…`, menu labels included.
- No `—`, no arrow or bullet glyphs (`→` `·` `⇒`) anywhere, except where the
  glyph is the payload (icon maps, UI labels). Use `-` or a new sentence.
- Replace, don't deprecate: no compat shims or dual paths unless I ask for a
  migration.

## Git

- Commit completed, green units on your own; list them (short hash + message)
  at the end of the reply.
- Never amend, rebase or reset commits you did not create in this session.
- Your worktrees: `<repo>/.claude/worktrees/<name>`, own branch, removed after
  the merge. Next to the repo is where mine land.
- Stage by naming paths, never `git add -A` or `.`. A bare `git add` only when
  a tool needs it (nix sees tracked files only), and say so.
- Conventional commits, lowercase, no trailing period, subject only, at most
  72 characters; a body only for a why the diff doesn't show. Merges too: a
  merge command handed to me carries `-m "<type>: ..."`, git's default
  message fails the commit-msg hook. A repo's own convention wins.
- No AI attribution, no trailers.
- Plain words: no critical, crucial, essential, significant, comprehensive,
  robust, elegant.

## Environment

- This config lives in nix-config `home/cli/claude/`. Never edit the deployed
  `~/.claude` copies; change the repo and tell me to deploy.
- Global skills, agents, commands and plugins come through nix
  (`home/cli/claude/default.nix`), so no `npx skills add -g`, no
  `claude plugin install`. Project ones (`<repo>/.claude/skills`,
  `<repo>/.agents/skills`) are yours to install.
- EGM artifact directory: .egm
  Relative to the working directory, so egm starts from the repo root.
- Task runner: mise. Read mise.toml before inventing commands.
