# docker runtime switcher: colima <-> orbstack. sourced by zsh (see home/cli/dev.nix).
# keeps only ONE VM running (two waste RAM) and point docker at its context.
# for per-project pick without stopping VMs use direnv `use docker` instead.
#
#   docker-use-colima  stop orbstack, start colima, use context colima
#   docker-use-orb     stop colima, start orbstack, use context orbstack
#   docker-use-status  show which runtime/context is active

# styled line with gum if there, else plain echo (gum can miss pre-rebuild)
_docker_use_say() {
  if command -v gum >/dev/null 2>&1; then
    gum style --foreground 212 "$@"
  else
    echo "$@"
  fi
}

# poll: wait until a context docker engine answer.
# kept as string so gum spin can run it as external command.
_docker_use_poll='i=0; until docker --context "$CTX" info >/dev/null 2>&1; do i=$((i+1)); [ "$i" -gt 60 ] && exit 1; sleep 0.5; done'

docker-use-colima() {
  _docker_use_say "→ switching to Colima"
  command -v orb >/dev/null 2>&1 && orb stop 2>/dev/null
  colima start || return 1
  docker context use colima >/dev/null
  _docker_use_say "✓ docker → $(docker context show 2>/dev/null)"
}

docker-use-orb() {
  _docker_use_say "→ switching to OrbStack"
  colima stop 2>/dev/null
  open -ga OrbStack || {
    echo "OrbStack not installed? run your rebuild first"
    return 1
  }
  if command -v gum >/dev/null 2>&1; then
    CTX=orbstack gum spin --title "waiting for OrbStack…" -- sh -c "$_docker_use_poll" ||
      { echo "OrbStack didn't come up within 30s"; return 1; }
  else
    CTX=orbstack sh -c "$_docker_use_poll" ||
      { echo "OrbStack didn't come up within 30s"; return 1; }
  fi
  docker context use orbstack >/dev/null
  _docker_use_say "✓ docker → $(docker context show 2>/dev/null)"
}

docker-use-status() {
  local active colima_s orb_s
  active="$(docker context show 2>/dev/null)"
  docker --context colima   info >/dev/null 2>&1 && colima_s="running" || colima_s="stopped"
  docker --context orbstack info >/dev/null 2>&1 && orb_s="running" || orb_s="stopped"
  if command -v gum >/dev/null 2>&1; then
    gum style --border rounded --padding "0 1" \
      "active context: $active" "colima:   $colima_s" "orbstack: $orb_s"
  else
    echo "active context: $active"
    echo "colima:   $colima_s"
    echo "orbstack: $orb_s"
  fi
}
