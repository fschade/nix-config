#!/usr/bin/env bash
# pattern borrowed with thanks from github.com/trailofbits/claude-code-config
set -euo pipefail

json="$(cat)"
cmd="$(jq -r '.tool_input.command // empty' <<<"$json")"
[ -z "$cmd" ] && exit 0

cmd="${cmd//\\$'\n'/ }"
cmd="${cmd//$'\n'/; }"

scan="$cmd"$'\n'"${cmd//[\'\"]/}"

grep -qE '(^|[^a-z0-9_-])(kubectl|helm|tofu|terraform)[[:space:]]' <<<"$scan" || exit 0
grep -qE '(kubectl[[:space:]]+[^;|&]*(apply|delete|create|replace|scale|patch|rollout|drain|cordon|uncordon|label|annotate|taint)|helm[[:space:]]+[^;|&]*(install|upgrade|uninstall|rollback)|(tofu|terraform)[[:space:]]+[^;|&]*(apply|destroy|import|taint|state[[:space:]]+(rm|mv)))' <<<"$scan" || exit 0

mkdir -p "$HOME/.claude/logs"
jq -cn \
  --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg cmd "$cmd" \
  '{ts: $ts, cmd: $cmd}' >>"$HOME/.claude/logs/mutations.jsonl"
exit 0
