# Global instructions

These apply in every project. Project-level CLAUDE.md files add to or override this.

## Communication

- Mirror my language: reply in German when I write German, in English when I write English. Code, comments, commit messages, and docs are always English.
- Be direct and concise. Lead with the result, then the reasoning. No filler, no cheerleading.

## Working style

- Small, clearly scoped tasks: just do them. Larger changes (refactors, new modules, anything touching many files): sketch the approach in a few lines first and get my OK before writing code.
- Verify work before calling it done: run the project's formatter/linter/tests when they exist. Look for mise tasks (mise.toml) first, then Makefile / package.json scripts / flake checks.
- Prefer the smallest diff that solves the problem. No drive-by refactors, no speculative abstractions, no over-engineering.
- Don't create documentation files (README, docs/) unless I ask for them.
- No new dependencies without asking — and no hand-rolling what an existing dependency already does (via jbarbier/CLAUDE.md, thanks).
- Stop and ask when: several valid approaches with real consequences, deleting or restructuring existing code, anything security-related, or a genuine comprehension gap (via obra/dotfiles + harperreed/dotfiles, thanks).

## Code style

- Match the surrounding code: naming, idioms, formatting, comment density.
- Comments: short and plain, only where the code can't speak for itself. Simple everyday English, slightly informal is fine — never polished AI-sounding boilerplate ("This function is responsible for...").
- Replace, don't deprecate: when replacing an implementation, remove the old one — no compat shims, no dual code paths, unless I ask for a migration.
- Never invent technical details: versions, env vars, API endpoints, config keys, CLI flags — look them up or say you don't know (via harperreed/dotfiles, thanks).

## Git & deployment

- NEVER push. Not on request completion, not "to wrap up", not ever — I always do that myself (enforced via deny rule too).
- Committing is fine, also on your own initiative — but only completed, coherent units (checks/tests green), and ALWAYS list what you committed (short hash + message) at the end of your reply so I keep the overview. Never commit half-working state.
- Never amend, rebase, or reset commits you did not create in this session.
- Deploy commands (`darwin-rebuild`, `mise run deploy`, `terraform`/`tofu apply`, `kubectl apply`, and anything comparable) never on your own initiative. Run one only when I explicitly ask for it. Some repos whitelist deploys via project permissions — that only skips the prompt, it does not change the "only when asked" part.
- Staging as part of your own commit is normal. Standalone `git add` (without committing) only when a tool genuinely needs it (nix flakes only see tracked files) — and say so when you did.
- Commit messages: conventional commits — `feat:`, `fix:`, `chore:`, `docs:`, `refactor:`, `test:` — lowercase, terse, no trailing period. Only exception: repos with a clearly different established convention (e.g. nixpkgs' `pkg: 1.2 -> 1.3`), then follow theirs.
- NEVER add Co-Authored-By, "Generated with", or any other Claude/AI attribution to commits or PRs. No trailers, no footers — the message ends with its content.
- Commit messages and PR text in plain, factual language — a bug fix is a bug fix, not a "critical stability improvement". Avoid: critical, crucial, essential, significant, comprehensive, robust, elegant.
- Never rewrite history on shared branches.

## Environment

- Main machine: Mac Studio (Apple Silicon, macOS), managed declaratively via nix-darwin + home-manager (`~/Developer/fschade/nix-config`).
- This global claude config is versioned in nix-config (`home/cli/claude/`) and is the golden rule: never edit `~/.claude/settings.json` or `~/.claude/CLAUDE.md` directly — change the repo copies and tell me to deploy. Project-specific permission extensions go into the project's own `.claude/settings.json` / `.claude/settings.local.json`.
- Preferred task runner: mise (`mise run <task>`). Check mise.toml for how to build/test/deploy before inventing commands.
- Homelab: Proxmox hosts + Kubernetes, config in `~/Developer/fschade/homelab`.
