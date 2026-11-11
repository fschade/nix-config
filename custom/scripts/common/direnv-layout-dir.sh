# shellcheck shell=bash
# state, not ~/.cache: nix-direnv evals the profile rc kept here, and the claude
# sandbox may write ~/.cache, so it could plant code for every project's shell
direnv_layout_dir() {
  echo "${direnv_layout_dir:-${XDG_STATE_HOME:-$HOME/.local/state}/direnv/layouts/${PWD#/}}"
}
