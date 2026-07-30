# shellcheck shell=bash
# direnv helper: pick docker runtime for THIS project, like `use flake`.
# loaded into direnv stdlib (see home/cli/core/cli.nix). in a .envrc:
#
#   use flake
#   use docker orb        # or: use docker colima
#
# it only export DOCKER_CONTEXT for the dir (direnv revert it on leave), so
# different projects can point to different runtimes at the same time. it dont
# start VMs: do that once with docker-use-orb / -colima.
use_docker() {
  local choice="${1:-colima}" ctx cmd
  case "$choice" in
    colima) ctx=colima; cmd=colima ;;
    orb | orbstack) ctx=orbstack; cmd=orb ;;
    *)
      log_error "use_docker: expected 'colima' or 'orb', got '$choice'"
      return 1
      ;;
  esac
  export DOCKER_CONTEXT="$ctx"
  if docker --context "$ctx" info >/dev/null 2>&1; then
    log_status "docker -> $ctx"
  else
    log_status "docker -> $ctx (engine down; start it: docker-use-$cmd)"
  fi
}
