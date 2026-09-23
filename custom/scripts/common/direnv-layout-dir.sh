# shellcheck shell=bash
direnv_layout_dir() {
  echo "${direnv_layout_dir:-${XDG_CACHE_HOME:-$HOME/.cache}/direnv/layouts/${PWD#/}}"
}
