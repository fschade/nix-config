# custom/

Home for anything that would otherwise be a large text blob inlined in a `.nix`
file. Keeping it out of Nix means real syntax highlighting, shellcheck/yaml
tooling, and clean diffs — the `.nix` just references it.

**Rule:** more than a few lines of non-Nix text (shell, YAML, config, templates)
→ put it here and wire it in with `.source = ./…` or `builtins.readFile ./…`.
Short one-liners can stay inline.

## Layout

| Dir | What | Wired via |
|---|---|---|
| `scripts/` | shell scripts (see `scripts/README.md`; split by `common`/`darwin`/`linux`) | `readFile` (sourced) or store-path (activation) |
| `config/` | config files that Nix drops into place (e.g. `config/colima/default.yaml`) | `.source` / `readFile` |
| `templates/` | project templates (e.g. `templates/copier/go-service`) | `xdg.dataFile.source` |
| `assets/` | binary assets (wallpapers, …) | `home.file.source` |

The platform gate (`lib.mkIf pkgs.stdenv.hostPlatform.isDarwin`, …) always stays
in Nix; the folders just document intent.
