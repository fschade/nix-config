# custom/scripts

Shell scripts as real files, so shellcheck and highlighting work. Nix pulls them
in with `builtins.readFile` (sourced functions) or a store path (executables and
activation scripts). Split by platform: `common/`, `darwin/`, `linux/`.

- Interactive scripts use [`gum`](https://github.com/charmbracelet/gum), guarded
  so they fall back to plain `echo` when it is missing.
- Activation scripts are non-interactive, so no gum. Nix-computed values come in
  as arguments.
- Sourced functions use bare tool names from PATH, activation scripts use
  explicit `${pkgs.foo}/bin/foo` store paths.
- Executables here run under `set -eu`, not the `set -euo pipefail` of
  `scripts/*.sh`: none of them pipes.
