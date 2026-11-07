#!/usr/bin/env bash
# reads the command through shfmt's syntax tree, so text in strings, heredocs and comments is never a command
# rules in bash-guard.jq, patterns borrowed with thanks from github.com/AnastasiyaW/claude-code-config
set -euo pipefail

block() {
  echo "BLOCKED by bash-guard: $1" >&2
  exit 2
}

json="$(cat)"
cmd="$(jq -r '.tool_input.command // empty' <<<"$json")" ||
  block "unreadable hook input. the guard does not let through what it cannot parse."
[ -z "$cmd" ] && exit 0

rules="$(dirname "$0")/bash-guard.jq"
ask=""
judge() { # $1 shell source, $2 depth of nested shells
  local ast found kind arg
  [ "$2" -gt 3 ] && block "shells nested deeper than the guard follows. run the inner command directly."
  ast="$(shfmt -ln bash --to-json <<<"$1" 2>&1)" ||
    block "shell syntax the guard cannot parse ($ast). write it as plain bash."
  found="$(jq -r -f "$rules" <<<"$ast")" ||
    block "the guard failed to read the syntax tree."
  while IFS=$'\t' read -r kind arg; do
    case "$kind" in
      block) block "$arg" ;;
      ask) ask="$arg" ;;
      shell) judge "$(jq -r . <<<"$arg")" $(($2 + 1)) ;;
    esac
  done <<<"$found"
}
judge "$cmd" 0

if [ -n "$ask" ]; then
  jq -n --arg r "$ask" \
    '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "ask", permissionDecisionReason: $r}}'
fi
exit 0
