# keep .direnv out of the project (direnv stdlib, see home/cli/core/cli.nix).
# nix-direnv parks the flake profile and one
# gc root per flake input in there, so every editor ends up indexing a tree of
# store symlinks and project-wide search fills with nixpkgs. the roots still
# have to exist, they just live under the cache now, mirroring the project path
# so you can tell which layout belongs to which checkout.
# the `direnv_layout_dir` variable is direnv's own per-project escape hatch, an
# .envrc that sets it keeps winning like it does with the stdlib version.
direnv_layout_dir() {
  echo "${direnv_layout_dir:-${XDG_CACHE_HOME:-$HOME/.cache}/direnv/layouts/${PWD#/}}"
}
