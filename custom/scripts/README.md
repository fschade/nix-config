# custom/scripts

Shell scripts as real files, so shellcheck and syntax highlighting work. Nix
pulls them in with `builtins.readFile` (sourced shell functions) or a store path
(executables and activation scripts). Split by platform: `common/`, `darwin/`,
`linux/`. The actual gate stays in nix, the folders just document intent.

## Conventions

- Interactive scripts use [`gum`](https://github.com/charmbracelet/gum) for
  output. Guard it so it fall back to plain `echo` when gum is missing.
- Activation scripts run non-interactive during `switch`, so they skip gum.
  Nix-computed values (store paths, usernames) come in as arguments.
- Sourced functions use bare tool names from PATH (`docker`, `colima`),
  activation scripts use explicit `${pkgs.foo}/bin/foo` store paths.
