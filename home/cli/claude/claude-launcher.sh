#!/usr/bin/env bash
# starts claude with the sandbox locked against repo settings, plus what .claude/outbound-hosts and ssh-hosts open
set -euo pipefail

real=@claude@

# a second --settings replaces the first instead of merging, so an explicit one goes through alone
for arg in "$@"; do
  case "$arg" in
    --settings | --settings=*) exec "$real" "$@" ;;
  esac
done

host_file() { # $1 file name below .claude
  local d="$PWD"
  while [ "$d" != "/" ]; do
    if [ -f "$d/.claude/$1" ]; then
      printf '%s\n' "$d/.claude/$1"
      return 0
    fi
    d="$(dirname "$d")"
  done
  return 1
}

# a cloned repo can ship these files, so their hosts only open on a yes from the user
read_hosts() { # $1 file name below .claude, $2 regex a line has to match, $3 what a yes opens
  local file list
  file="$(host_file "$1")" || return 0
  list="$(grep -vE '^[[:space:]]*(#|$)' "$file" | tr -d '[:blank:]' | tr '[:upper:]' '[:lower:]')" || return 0
  if grep -qvE "$2" <<<"$list"; then
    echo "claude: $file holds something other than exact hosts, ignored" >&2
    return 0
  fi
  if ! { [ -t 0 ] && [ -t 2 ]; }; then
    echo "claude: no terminal to confirm $file, ignored" >&2
    return 0
  fi
  printf 'claude: %s %s:\n%s\nallow? [y/N] ' "$file" "$3" "$list" >&2
  local answer=""
  read -r answer || true
  [ "$answer" = "y" ] && printf '%s\n' "$list"
  return 0
}

# a wildcard only as *.domain.tld, never * or *.tld
outbound="$(read_hosts outbound-hosts '^((\*\.[a-z0-9-]+\.)?[a-z0-9.-]+|\[[0-9a-f:]+\])$' 'opens for this session')"
remote="$(read_hosts ssh-hosts '^([a-z0-9_][a-z0-9._-]*@)?(\*\.[a-z0-9-]+\.)?[a-z0-9][a-z0-9.-]*$' 'leaves the sandbox for ssh, every call still asks')"

settings="$(@jq@ -cn --arg outbound "$outbound" --arg remote "$remote" '
  def lines: split("\n") | map(select(length > 0));
  {disableAllHooks: false, sandbox: {
    allowUnsandboxedCommands: false,
    network: {allowedDomains: ($outbound | lines)},
    excludedCommands: [($remote | lines)[] as $h |
      "ssh \($h) *", "autossh \($h) *", "mosh \($h) *", "sftp \($h) *",
      "scp * \($h):*", "scp \($h):* *", "rsync * \($h):*", "rsync \($h):* *"]
  }}')"
exec "$real" --settings "$settings" "$@"
