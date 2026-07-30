# custom/

Non-Nix text that would otherwise be a big inline blob in a `.nix` file. Out
here it gets real syntax highlighting, shellcheck/yaml tooling and clean diffs;
the `.nix` only references it.

Rule of thumb: more than a few lines of shell, YAML, config or template text goes
here and gets wired with `.source = ./...` or `builtins.readFile ./...`.
One-liners stay inline.

| Dir | What | Wired via |
|---|---|---|
| `scripts/` | shell scripts, split by `common`/`darwin`/`linux` (see `scripts/README.md`) | `readFile` or store path |
| `config/` | config files, most dropped into place by nix (`config/colima/`), some just versioned for a manual import (`config/keyboard/`) | `.source` / `readFile`, or nothing |
| `templates/` | project templates (e.g. `templates/copier/go-service`) | `xdg.dataFile.source` |
| `web-apps/` | web-app manifests (see `tools/web-app/README.md`) | read by the swift builder |
| `assets/` | binary assets (wallpapers, ...) | `home.file.source` |

The platform gate (`lib.mkIf pkgs.stdenv.hostPlatform.isDarwin`) always stays in
nix, the folders just document intent.
