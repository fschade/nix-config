#!/usr/bin/env bash
# claude code PreToolUse guard for Read. same split as the push rule: the
# Read() deny in settings.json catches the plain names (.env, .env.local,
# .env.*.local), this guard the rest (.env.production, config/.env), with the
# same rule bash-guard applies to shell readers. otherwise the Read tool opens
# what `cat` blocks. input: tool call json on stdin. block: stderr + exit 2.
set -euo pipefail

block() {
  echo "BLOCKED by read-guard: $1" >&2
  exit 2
}

# block on a payload we cannot parse, like bash-guard: any exit but 2 is
# non-blocking, so failing open would let an unchecked read through.
file="$(jq -r '.tool_input.file_path // empty')" ||
  block "unreadable hook input. the guard does not let through what it cannot parse."
[ -z "$file" ] && exit 0

# mirror of bash-guard's env rule: the exception belongs to a name, so the
# template names pass first and whatever `.env` is left is the one with the
# secrets. the suffix is one segment, so .envrc stays readable, same as there.
base="${file##*/}"
case "$base" in
.env.example | .env.sample | .env.template | .env.dist) exit 0 ;;
esac
grep -qE '^\.env(\.[A-Za-z0-9_-]+)?$' <<<"$base" &&
  block ".env files hold secrets. templates (.env.example etc) are fine to read."

exit 0
