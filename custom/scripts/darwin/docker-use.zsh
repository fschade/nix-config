# docker runtime switcher: colima <-> orbstack. sourced by zsh (see home/cli/dev.nix).
# keeps only ONE VM running (two waste RAM) and point docker at its context.
# for per-project pick without stopping VMs use direnv `use docker` instead.

# gum can be missing before the first rebuild, so this falls back to echo
_docker_use_say() {
  if command -v gum >/dev/null 2>&1; then
    gum style --foreground 212 "$@"
  else
    echo "$@"
  fi
}

# DOCKER_CONTEXT beats the context we just set, so in a dir with `use docker` in
# its .envrc the switch does nothing for this shell. the line above only talks
# about the default context, this one says the shell wont follow it
_docker_use_check_override() {
  if [ -n "${DOCKER_CONTEXT:-}" ] && [ "$DOCKER_CONTEXT" != "$1" ]; then
    _docker_use_say "! DOCKER_CONTEXT=$DOCKER_CONTEXT is set here (direnv \`use docker\` sets it, an export does too), docker in this shell keeps talking to $DOCKER_CONTEXT"
  fi
}

# wait until the context engine answer. kept as string so gum spin can run it
# as external command.
_docker_use_poll='i=0; until docker --context "$CTX" info >/dev/null 2>&1; do i=$((i+1)); [ "$i" -gt 60 ] && exit 1; sleep 0.5; done'

docker-use-colima() {
  _docker_use_say "-> switching to Colima"
  command -v orb >/dev/null 2>&1 && orb stop 2>/dev/null
  colima start || return 1
  docker context use colima >/dev/null
  _docker_use_say "✓ colima up, default docker context is colima"
  _docker_use_check_override colima
}

docker-use-orb() {
  _docker_use_say "-> switching to OrbStack"
  colima stop 2>/dev/null
  open -ga OrbStack || {
    echo "OrbStack not installed? run your rebuild first"
    return 1
  }
  if command -v gum >/dev/null 2>&1; then
    CTX=orbstack gum spin --title "waiting for OrbStack..." -- sh -c "$_docker_use_poll" ||
      { echo "OrbStack didn't come up within 30s"; return 1; }
  else
    CTX=orbstack sh -c "$_docker_use_poll" ||
      { echo "OrbStack didn't come up within 30s"; return 1; }
  fi
  docker context use orbstack >/dev/null
  _docker_use_say "✓ orbstack up, default docker context is orbstack"
  _docker_use_check_override orbstack
}

docker-use-status() {
  local default colima_s orb_s
  # `docker context show` reports DOCKER_CONTEXT back when it is set, so ask
  # without it to get the persisted default and let the check below name the
  # override
  default="$(unset DOCKER_CONTEXT; docker context show 2>/dev/null)"
  docker --context colima   info >/dev/null 2>&1 && colima_s="running" || colima_s="stopped"
  docker --context orbstack info >/dev/null 2>&1 && orb_s="running" || orb_s="stopped"
  if command -v gum >/dev/null 2>&1; then
    gum style --border rounded --padding "0 1" \
      "default context: $default" "colima:   $colima_s" "orbstack: $orb_s"
  else
    echo "default context: $default"
    echo "colima:   $colima_s"
    echo "orbstack: $orb_s"
  fi
  _docker_use_check_override "$default"
}
