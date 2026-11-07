#!/usr/bin/env bash
# WebFetch runs outside the sandbox. a WebFetch(domain:...) allow rule would open the host to the shell too
set -euo pipefail

json="$(cat)"
url="$(jq -r '.tool_input.url // empty' <<<"$json")" || {
  echo "BLOCKED by webfetch-guard: unreadable hook input. it does not let through what it cannot parse." >&2
  exit 2
}
url="$(tr '[:upper:]' '[:lower:]' <<<"$url")"

decision=ask
# no userinfo, no port, anything else about the authority ends in ask
if [[ "$url" =~ ^https?://([a-z0-9.-]+)([/?#]|$) ]]; then
  case "${BASH_REMATCH[1]}" in
  code.claude.com | docs.claude.com | platform.claude.com | \
    github.com | docs.github.com | raw.githubusercontent.com | \
    nixos.org | search.nixos.org | wiki.nixos.org | nix.dev | mise.jdx.dev | \
    developer.apple.com | developer.mozilla.org | man7.org | man.openbsd.org | www.rfc-editor.org | \
    docs.python.org | pypi.org | go.dev | pkg.go.dev | docs.rs | crates.io | nodejs.org | www.npmjs.com)
    decision=allow
    ;;
  esac
fi

jq -n --arg d "$decision" --arg r "webfetch-guard: $decision for this host" \
  '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: $d, permissionDecisionReason: $r}}'
