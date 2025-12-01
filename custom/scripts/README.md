# custom/scripts

Longer shell scripts live here as real files (shellcheck-able, syntax-highlighted,
diff-friendly) instead of inline `''…''` blocks in `.nix`. Nix wires them in via
`builtins.readFile` (for sourced shell functions) or a store-path reference (for
executables / activation scripts).

Rule of thumb: more than a few lines of shell → put it here.

## Layout (by platform)

- `common/` — runs on both macOS and Linux
- `darwin/` — macOS-only (colima, orbstack, mysides, osascript, …)
- `linux/`  — Linux-only

The platform gate stays in Nix (`lib.mkIf pkgs.stdenv.hostPlatform.isDarwin`, etc.);
the folder just documents intent and keeps things tidy.

## Conventions

- Interactive, user-facing scripts use [`gum`](https://github.com/charmbracelet/gum)
  for nice output (headers, spinners, styled status). Guard usage so it degrades to
  plain `echo` if gum is absent.
- Activation scripts (run during `darwin-rebuild switch`, non-interactive) stay plain
  — no gum. Pass Nix-computed values (store paths, usernames) in via env vars.
- Prefer bare tool names (`docker`, `colima`, `gum`) resolved from PATH for sourced
  functions; use explicit `${pkgs.foo}/bin/foo` store paths for activation scripts.

## Wired-in scripts

| Script | Platform | How it's wired | Where |
|---|---|---|---|
| `darwin/docker-use.zsh` | darwin | sourced into zsh (`readFile`) | `home/cli/dev.nix` |
| `darwin/direnv-use-docker.sh` | darwin | direnv `stdlib` (`readFile`, gated) → `use docker` | `home/cli/core/cli.nix` |
| `darwin/defaults-postactivation.sh` | darwin | activation (store path + args) | `modules/darwin/defaults.nix` |
| `darwin/login-items.sh` | darwin | activation (store path + args) | `modules/darwin/login-items.nix` |
| `darwin/set-wallpaper.sh` | darwin | activation (store path + args) | `home/gui/wallpaper.nix` |
