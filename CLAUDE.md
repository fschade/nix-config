# nix-config

Declarative setup for my machines: nix-darwin plus home-manager, one flake.
`README.md` has the commands, `MANUAL.md` the steps nix cannot do, and every
manual step a change creates belongs there.

## Layout

- `hosts/` host profiles, not one file per machine: three pve boxes share
  `hosts/pve-server.nix`. The machine list is `darwinHosts` / `homeHosts` in
  `flake.nix`, `templates/` holds the hostless generic configs. A darwin host
  is a full system config, a linux host is home-manager only. Home
  configurations are keyed `<user>@<host>`.
- `modules/darwin/` system level, nix-darwin options
- `home/` user level, split `cli` / `gui` / `os`. One tree there is payload, not
  config for this repo: `home/cli/claude/` becomes `~/.claude` and applies in
  every project, so a change to it is a global change that goes live on the next
  deploy, and the conventions inside it are not this repo's.
- `custom/` non-Nix payload: shell, config, templates, assets. What goes there
  and how it gets wired is `custom/README.md`.
- `scripts/` the bodies behind the mise tasks
- `tools/` self-contained tooling, own README (`tools/web-app`)

A module is a single `.nix` file. It becomes a directory with `default.nix`
only when it needs siblings: several modules that read better split
(`home/cli/core`), or payload travelling with it (`home/gui/aerospace`). The
`default.nix` is then the bare imports list or the module itself, whichever the
directory calls for.

## Conventions

- User and host are never hardcoded. `vars` comes through `specialArgs` from
  `flake.nix`: `vars.user.name`, `.fullName`, `.email`.
- Platform gates stay in nix (`lib.mkIf pkgs.stdenv.hostPlatform.isDarwin`).
  The `common` / `darwin` split under `custom/scripts/` only documents intent.
- `scripts/*.sh`: `#!/usr/bin/env bash`, `set -euo pipefail`, and `cd` to the
  repo root where paths are relative. Sourced fragments under `custom/scripts/`
  have no shebang and declare their dialect with `# shellcheck shell=bash`, or
  the gate skips them.
- Vendored files carry a `vendored` marker in their first five lines and keep
  their LICENSE. The shell gate skips them, they are upstream's to lint.
- A change to a claude guard hook or the statusline ships with its cases in
  `home/cli/claude/hooks/run-tests.sh`.

## Gates

`mise run check`: alejandra, deadnix, statix, shellcheck, a swift parse check,
gitleaks over both the tree and the history. `mise run claude-hooks-test` is
the hook suite. lefthook runs check on commit with `CHECK_SKIP_HOOK_TESTS=1`
and the suite only when hook or statusline files are staged, so committing is
the gate; `mise run fmt` formats.

## Careful with

- Nix only sees tracked files. A new file needs `git add` before a build, or it
  is invisible and the error points somewhere else.
- `mise run deploy` only when asked.
