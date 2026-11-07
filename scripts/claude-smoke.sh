#!/usr/bin/env bash
# headless probes against the deployed claude config, one haiku session plus one sonnet subagent
set -euo pipefail

work="$(cd "$(mktemp -d)" && pwd -P)"
transcripts="$HOME/.claude/projects/${work//[^A-Za-z0-9]/-}"
# denyRead globs start at the home directory, the temp dir above is outside them
mkdir -p "$HOME/.cache"
secrets="$(mktemp -d "$HOME/.cache/claude-smoke.XXXXXX")"
trap 'rm -rf "$work" "$transcripts" "$secrets"' EXIT

fail=0
ok() { echo "ok   $1"; }
bad() {
  echo "FAIL $1"
  fail=1
}

cd "$work"
echo "Use the Agent tool once with subagent_type general-purpose and the prompt 'reply with the word ok'. Then reply done." |
  claude -p --model haiku --max-turns 4 --output-format stream-json --verbose --allowedTools=Agent >stream.jsonl 2>stderr.txt
init="$(jq -c 'select(.subtype == "init")' stream.jsonl | head -n1)"

# claude reports rejected settings on stderr and carries on, so any output there is a finding
if [ -s stderr.txt ]; then
  bad "claude wrote to stderr:"
  sed 's/^/     /' stderr.txt
else
  ok "no settings warnings"
fi
[ -n "$init" ] || {
  echo "FAIL no init event, claude did not start"
  exit 1
}
echo "claude $(jq -r .claude_code_version <<<"$init")"

if jq -e '.plugins | any(.name == "egm")' <<<"$init" >/dev/null; then
  ok "egm plugin loaded"
else
  bad "egm plugin missing"
fi

off="$(jq -c '[.skillOverrides // {} | to_entries[] | select(.value == "off") | .key]' "$HOME/.claude/settings.json")"
stray="$(jq -r --argjson off "$off" '[.skills[] | select(. as $s | $off | index($s))] | join(" ")' <<<"$init")"
if [ -z "$stray" ]; then
  ok "skills set to off are gone"
else
  bad "skills set to off still listed: $stray"
fi

if jq -e '.plugins | any(.name == "cc-plugin-plugin-authoring")' <<<"$init" >/dev/null; then
  bad "builtin plugin-authoring still enabled"
else
  ok "builtin plugin-authoring off"
fi

idea="$(jq -r '[.mcp_servers[] | select(.name == "idea") | .source] | join(" ")' <<<"$init")"
if [ -n "$idea" ]; then
  ok "idea mcp server present (source: $idea)"
else
  bad "idea mcp server missing"
fi

models="$(find "$transcripts" -path '*/subagents/*' -name '*.jsonl' -exec grep -ho '"model":"claude[^"]*"' {} + 2>/dev/null | sort -u)"
if grep -q sonnet <<<"$models"; then
  ok "subagents default to sonnet"
else
  bad "subagent model is not sonnet: ${models:-no subagent transcript}"
fi

if command -v rtk >/dev/null; then
  ok "rtk on PATH"
else
  bad "rtk missing, the Bash hook cannot run"
fi

for name in .env .env.local .env.example id_ed25519 .envrc credentials.json server.pem server.key .pgpass cacert.pem; do
  echo dummy >"$secrets/$name"
done
repo="$secrets/repo"
mkdir "$repo"
echo dummy >"$repo/.envrc"
echo dummy >"$repo/tracked"
git -C "$repo" init -q
git -C "$repo" add .envrc tracked
git -C "$repo" -c user.name=smoke -c user.email=smoke@example.com -c commit.gpgsign=false commit -qm init
# a script, so the sandbox answers and not the hooks reading the command line
cat >probe.sh <<EOF
for host in example.com uploads.github.com github.com api.github.com; do
  curl -sS -o /dev/null -m 15 "https://\$host/"; echo \$? >"\$host.rc"
done
for name in .env .env.local .env.example id_ed25519 .envrc credentials.json server.pem server.key .pgpass cacert.pem; do
  cat "$secrets/\$name" >/dev/null; echo \$? >"read\$name.rc"
done
mv "$secrets/.env" "$secrets/moved"
cat "$secrets/moved" >/dev/null; echo \$? >read-moved.rc
git -C "$repo" status --short >/dev/null; echo \$? >git-status.rc
git -C "$repo" diff >/dev/null; echo \$? >git-diff.rc
echo x >>"$repo/tracked"
git -C "$repo" stash create >/dev/null; echo \$? >git-stash.rc
[ "\${SMOKE_AGENT_KEY:-}" = dummy ]; echo \$? >agent-env.rc
EOF
echo 'Run this once with the Bash tool, exactly as written, then reply done: sh probe.sh' |
  SMOKE_AGENT_KEY=dummy claude -p --model haiku --max-turns 3 --allowedTools=Bash >/dev/null || bad "sandbox probe session failed"
probed() { # $1 rc file, $2 open or refused, $3 label
  local rc
  rc="$(cat "$1.rc" 2>/dev/null || echo none)"
  if { [ "$2" = open ] && [ "$rc" = 0 ]; } || { [ "$2" = refused ] && [ "$rc" != 0 ] && [ "$rc" != none ]; }; then
    ok "$3"
  else
    bad "$3: rc $rc"
  fi
}
probed example.com refused "sandbox refuses a host off the list"
probed uploads.github.com refused "sandbox refuses a github host off the list"
# the launcher passes an empty host list, github answering means lists merge across settings scopes
probed github.com open "sandbox lets a listed host through"
probed api.github.com open "sandbox lets an exact github host through"
probed read.env refused "sandbox refuses .env"
probed read.env.local refused "sandbox refuses .env.local"
probed read.env.example open "sandbox reads .env.example"
probed readid_ed25519 refused "sandbox refuses a private key by name"
probed read-moved refused "sandbox refuses .env after a rename"
probed read.envrc open "sandbox reads .envrc, secrets live in .env"
probed readcredentials.json refused "sandbox refuses credentials.json"
probed readserver.pem refused "sandbox refuses a .pem"
probed readserver.key refused "sandbox refuses a .key"
probed read.pgpass refused "sandbox refuses .pgpass"
probed readcacert.pem open "sandbox reads a ca bundle"
probed git-status open "git status works beside a tracked .envrc"
probed git-diff open "git diff works beside a tracked .envrc"
probed git-stash open "git stash works beside a tracked .envrc, lefthook needs it"
probed agent-env open "the session env reaches the sandboxed shell"

exit "$fail"
