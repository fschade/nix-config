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

# `"kubectl" apply` would walk past the CLI match, so scan a quote-stripped copy
# as a second line too, same as bash-guard does.
scan="$cmd"$'\n'"${cmd//[\'\"]/}"

# the CLI is matched as a word, like bash-guard does it, not anchored on a
# separator: an anchor drops everything with something in front, `sudo kubectl`,
# a kubectl inside a for loop, behind xargs or in a find -exec. those batch runs
# are exactly the ones worth having in the log.
grep -qE '(^|[^a-z0-9_-])(kubectl|helm|tofu|terraform)[[:space:]]' <<<"$scan" || exit 0
grep -qE '(kubectl[[:space:]]+[^;|&]*(apply|delete|create|replace|scale|patch|rollout|drain|cordon|uncordon|label|annotate|taint)|helm[[:space:]]+[^;|&]*(install|upgrade|uninstall|rollback)|(tofu|terraform)[[:space:]]+[^;|&]*(apply|destroy|import|taint|state[[:space:]]+(rm|mv)))' <<<"$scan" || exit 0

# no exit code: the bash tool response carries none, so the field this used to
# write was "?" on every single line. what ran is the part worth keeping.
mkdir -p "$HOME/.claude/logs"
jq -cn \
  --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg cmd "$cmd" \
  '{ts: $ts, cmd: $cmd}' >>"$HOME/.claude/logs/mutations.jsonl"
exit 0
