#!/usr/bin/env bash
# claude code PostToolUse audit log: append a jsonl line for every infra
# MUTATION claude ran (kubectl/helm/tofu/terraform). reads are skipped, never
# blocks anything. log: ~/.claude/logs/mutations.jsonl
# pattern borrowed with thanks from github.com/trailofbits/claude-code-config
# (log-gam.sh), adapted from google workspace to the homelab CLIs.
set -euo pipefail

json="$(cat)"
cmd="$(jq -r '.tool_input.command // empty' <<<"$json")"
[ -z "$cmd" ] && exit 0

grep -qE '(^|[;&|][[:space:]]*)(kubectl|helm|tofu|terraform)[[:space:]]' <<<"$cmd" || exit 0
grep -qE '(kubectl[[:space:]]+[^;|&]*(apply|delete|create|replace|scale|patch|rollout|drain|cordon|uncordon|label|annotate|taint)|helm[[:space:]]+[^;|&]*(install|upgrade|uninstall|rollback)|(tofu|terraform)[[:space:]]+[^;|&]*(apply|destroy|import|taint|state[[:space:]]+(rm|mv)))' <<<"$cmd" || exit 0

mkdir -p "$HOME/.claude/logs"
jq -cn \
  --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg rc "$(jq -r '.tool_response.exit_code // .tool_result.exit_code // "?"' <<<"$json")" \
  --arg cmd "$cmd" \
  '{ts: $ts, rc: $rc, cmd: $cmd}' >>"$HOME/.claude/logs/mutations.jsonl"
exit 0
