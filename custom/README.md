# custom/

Non-Nix text that would otherwise be an inline blob in a `.nix` file. Out here it
gets syntax highlighting, shellcheck/yaml tooling and clean diffs.

More than a few lines of shell, YAML, config or template text goes here, wired
with `.source = ./...` or `builtins.readFile ./...`. One-liners stay inline. A
script belonging to exactly one module travels with it instead (claude hooks,
statusline, sketchybar plugins).

| Dir | What | Wired via |
|---|---|---|
| `scripts/` | shell scripts, split by `common`/`darwin`/`linux` | `readFile` or store path |
| `config/` | config files, dropped into place or versioned for a manual import | `.source` / `readFile`, or nothing |
| `templates/` | project templates | `xdg.dataFile.source` |
| `web-apps/` | web-app manifests (see `tools/web-app/README.md`) | read by the swift builder |
| `assets/` | binary assets (wallpapers, ...) | `home.file.source` |

The platform gate (`lib.mkIf pkgs.stdenv.hostPlatform.isDarwin`) stays in nix,
the folders only document intent.
