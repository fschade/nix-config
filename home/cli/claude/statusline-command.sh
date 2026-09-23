#!/bin/sh
input=$(cat)

cwd=$(echo "$input" | jq -r '.cwd // empty')
home="$HOME"
case "$cwd" in
  "$home"/*) dir="~${cwd#"$home"}" ;;
  "$home")   dir="~" ;;
  *)         dir="$cwd" ;;
esac

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

model=$(echo "$input" | jq -r '.model.display_name // empty')

# field borrowed with thanks from github.com/trailofbits/claude-code-config.
ctx=$(echo "$input" | jq -r '.context_window.remaining_percentage // empty')
ctx=${ctx%.*}
ctxout=""
case "$ctx" in
  '' | *[!0-9]*) ;; # missing or not a number -> no ctx segment
  *)
    esc=$(printf '\033')
    if [ "$ctx" -le 20 ]; then
      ctxout="${esc}[31mctx ${ctx}%${esc}[0m"
    else
      ctxout="ctx ${ctx}%"
    fi
    ;;
esac

out="$dir"
[ -n "$branch" ] && out="$out  $branch"
[ -n "$model"  ] && out="$out  $model"
[ -n "$ctxout" ] && out="$out  $ctxout"

printf '%s' "$out"
