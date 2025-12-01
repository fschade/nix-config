#!/bin/sh
# Claude Code status line: dir | git branch[*] | model
input=$(cat)

# current dir with ~ abbreviation
cwd=$(echo "$input" | jq -r '.cwd // empty')
home="$HOME"
case "$cwd" in
  "$home"/*) dir="~${cwd#$home}" ;;
  "$home")   dir="~" ;;
  *)         dir="$cwd" ;;
esac

# git branch + dirty flag (skip optional lock file)
branch=""
if git -C "$cwd" --no-optional-locks rev-parse --is-inside-work-tree 2>/dev/null | grep -q true; then
  branch=$(git -C "$cwd" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null)
  if [ -z "$branch" ]; then
    branch=$(git -C "$cwd" --no-optional-locks rev-parse --short HEAD 2>/dev/null)
  fi
  if ! git -C "$cwd" --no-optional-locks diff --quiet 2>/dev/null || \
     ! git -C "$cwd" --no-optional-locks diff --cached --quiet 2>/dev/null; then
    branch="${branch}*"
  fi
fi

# model display name
model=$(echo "$input" | jq -r '.model.display_name // empty')

# context window left, red when it gets tight (auto compact comes near 0).
# field borrowed with thanks from github.com/trailofbits/claude-code-config.
ctx=$(echo "$input" | jq -r '.context_window.remaining_percentage // empty')
ctxout=""
if [ -n "$ctx" ]; then
  ctx=${ctx%.*}
  esc=$(printf '\033')
  if [ "$ctx" -le 20 ]; then
    ctxout="${esc}[31mctx ${ctx}%${esc}[0m"
  else
    ctxout="ctx ${ctx}%"
  fi
fi

# assemble
out="$dir"
[ -n "$branch" ] && out="$out  $branch"
[ -n "$model"  ] && out="$out  $model"
[ -n "$ctxout" ] && out="$out  $ctxout"

printf '%s' "$out"
