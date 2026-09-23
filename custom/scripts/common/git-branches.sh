# shellcheck shell=bash

default_pattern='^(main|master|develop|(feat|fix|chore|docs|refactor|test|ci|release|hotfix)/[a-z0-9]+([.-][a-z0-9]+)*)$'

usage() {
  echo "usage: git branches [--all] [--root DIR] [--verbose] | git branches --check" >&2
  exit 2
}

all=0 verbose=0 check=0 root="$HOME/Developer"
while [ $# -gt 0 ]; do
  case "$1" in
  -a | --all) all=1 ;;
  -v | --verbose) verbose=1 ;;
  -c | --check) check=1 ;;
  --root)
    shift
    [ $# -gt 0 ] || usage
    root="$1"
    all=1
    ;;
  *) usage ;;
  esac
  shift
done

dir=.
g() { git -C "$dir" "$@"; }
pattern() { g config --get branches.pattern || echo "$default_pattern"; }

if [ "$check" = 1 ]; then
  name="$(g symbolic-ref -q --short HEAD || true)"
  [ -z "$name" ] && exit 0 # detached head, nothing to name
  pat="$(pattern)"
  [[ "$name" =~ $pat ]] && exit 0
  echo "branch '$name' is off the convention <type>/<issue>-<description>: $pat" >&2
  exit 1
fi

base_ref() {
  local ref b
  ref="$(g symbolic-ref -q refs/remotes/origin/HEAD || true)"
  if [ -n "$ref" ]; then
    echo "$ref"
    return
  fi
  for b in main master develop; do
    if g show-ref -q --verify "refs/remotes/origin/$b"; then
      echo "refs/remotes/origin/$b"
      return
    fi
    if g show-ref -q --verify "refs/heads/$b"; then
      echo "refs/heads/$b"
      return
    fi
  done
}

repos=0 branches=0 flagged=0
report() { # $1 label printed before the first flagged line, empty for none
  local pat base name up track age head flags n shown=0
  pat="$(pattern)"
  base="$(base_ref)"
  repos=$((repos + 1))
  while IFS=$'\x1f' read -r name up track age head; do
    branches=$((branches + 1))
    flags=""
    if [ -z "$up" ]; then
      flags="local"
    else
      case "$track" in *gone*) flags="gone" ;; esac
      n="$(sed -nE 's/.*behind ([0-9]+).*/\1/p' <<<"$track")"
      [ -n "$n" ] && flags="$flags behind $n"
      n="$(sed -nE 's/.*ahead ([0-9]+).*/\1/p' <<<"$track")"
      [ -n "$n" ] && flags="$flags ahead $n"
    fi
    case "$name" in
    main | master | develop) ;;
    *)
      if [ -n "$base" ] && g merge-base --is-ancestor "$name" "$base" 2>/dev/null; then
        flags="$flags merged"
      fi
      ;;
    esac
    [[ "$name" =~ $pat ]] || flags="$flags name"
    [ "$head" = "*" ] && flags="$flags current"
    flags="${flags# }"
    [ -n "$flags" ] && flagged=$((flagged + 1))
    [ -z "$flags" ] && [ "$verbose" = 0 ] && continue
    if [ "$shown" = 0 ] && [ -n "$1" ]; then
      printf '\n%s\n' "$1"
      shown=1
    fi
    printf '  %-48s %-16s %s\n' "$name" "$age" "$flags"
  done < <(g for-each-ref --sort=committerdate \
    --format='%(refname:short)%1f%(upstream:short)%1f%(upstream:track)%1f%(committerdate:relative)%1f%(HEAD)' \
    refs/heads/)
}

if [ "$all" = 1 ]; then
  for dir in "$root"/*/*/; do
    [ -d "$dir/.git" ] || continue
    dir="${dir%/}"
    report "${dir#"$root"/}"
  done
  printf '\n%d repos, %d branches, %d flagged\n' "$repos" "$branches" "$flagged"
else
  g rev-parse --git-dir >/dev/null
  report ""
  printf '%d branches, %d flagged\n' "$branches" "$flagged"
fi
