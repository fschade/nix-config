# shellcheck shell=bash
# keep .direnv out of the project (direnv stdlib, see home/cli/core/cli.nix).
# nix-direnv puts the flake profile and a gc root per input under here, so with
# .direnv in the tree every editor indexes a pile of store symlinks and repo
# search fills with nixpkgs. the roots live in the cache instead, mirroring the
# project path so you can tell which layout belongs to which checkout.
# direnv_layout_dir is direnv's own per-project escape hatch: an .envrc that sets
# it still wins, like with the stdlib version.
direnv_layout_dir() {
  echo "${direnv_layout_dir:-${XDG_CACHE_HOME:-$HOME/.cache}/direnv/layouts/${PWD#/}}"
}
