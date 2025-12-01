#!/usr/bin/env bash
# claude code PreToolUse guard for Bash. blocks destructive command shapes that
# plain deny globs cant catch (flag permutations, compound commands, sh -c
# wrappers — we scan the whole command string, so wrapped one-liners match too).
# input: tool call json on stdin. block: message on stderr + exit 2.
#
# patterns borrowed with thanks from:
#   github.com/trailofbits/claude-code-config (rm flag permutations, pipe-to-shell)
#   github.com/AnastasiyaW/claude-code-config (destructive git/k8s, secret readers)
#   github.com/davila7/claude-code-templates (interpreter wrapper idea)
# trimmed and rewritten for this setup.
set -euo pipefail

cmd="$(jq -r '.tool_input.command // empty')"
[ -z "$cmd" ] && exit 0

block() {
  echo "BLOCKED by bash-guard: $1" >&2
  exit 2
}

has() { grep -qiE "$1" <<<"$cmd"; }
hasC() { grep -qE "$1" <<<"$cmd"; } # case sensitive, for -D vs -d style flags

# rm with recursive+force in any flag spelling (-rf, -fR, -r -f, behind && ...).
# false positives on unrelated flags in compound commands are fine: split the
# command or delete without -f.
if has '(^|[;&|][[:space:]]*)rm[[:space:]]' &&
  has '(^|[[:space:]])-[a-z]*r|--recursive' &&
  has '(^|[[:space:]])-[a-z]*f|--force'; then
  block "rm with recursive+force. delete precisely (no -f) or leave it to the user."
fi

# destructive git: history rewrites and mass discards. push is denied wholesale
# in settings, commit needs an explicit ask (see CLAUDE.md).
hasC 'git[[:space:]]+branch[[:space:]]+(-[a-zA-Z]*D|--delete[[:space:]]+--force|--force[[:space:]]+--delete)' &&
  block "git branch -D. use -d or let the user force it."
has 'git[[:space:]]+clean[[:space:]]+[^;|&]*-[a-z]*f' &&
  block "git clean -f. untracked files are not yours to bulk delete."
has 'git[[:space:]]+(checkout|restore)[[:space:]]+([^;|&]*[[:space:]])?(--[[:space:]]+)?\.([[:space:]]|$)' &&
  block "mass discard of working tree changes."
has 'git[[:space:]]+reset[[:space:]]+[^;|&]*--hard' &&
  block "git reset --hard."
has 'git[[:space:]]+(filter-branch|reflog[[:space:]]+expire|gc[[:space:]]+[^;|&]*--prune=now)' &&
  block "git history rewrite/expire."
# two independent configs converged on this one: harperreed/dotfiles and
# jbarbier/CLAUDE.md, thanks.
has 'git[[:space:]][^;|&]*--no-(verify|hooks|pre-commit-hook)' &&
  block "bypassing git hooks (--no-verify). fix what the hook complains about."

# homelab mass destruction
has 'kubectl[[:space:]]+delete[[:space:]]+(ns|namespace)([[:space:]]|$)' &&
  block "kubectl delete namespace."
has 'kubectl[[:space:]]+delete[[:space:]]+[^;|&]*--all([[:space:]]|$)' &&
  block "kubectl delete --all."
has 'docker[[:space:]]+system[[:space:]]+prune[[:space:]]+[^;|&]*(-[a-z]*a|--volumes)' &&
  block "docker system prune -a/--volumes."

# pipe from the internet straight into a shell (also via sudo)
has '(curl|wget)[[:space:]][^;|&]*\|[[:space:]]*(sudo[[:space:]]+)?(ba|z|da)?sh([[:space:]]|$)' &&
  block "piping a download into a shell. download, inspect, then run."

# wrappers around a force-recursive rm: sh -c "rm -rf ...", python -c, but
# also xargs/find -exec/command/env. the plain rm rule above anchors on
# separators, so wrapped forms need this one.
if { has '(sh|python3?|node|perl|ruby)[[:space:]]+-[ce][[:space:]]' ||
  has '(^|[;&|][[:space:]]*)(xargs|command|env)[[:space:]]' ||
  has 'find[[:space:]][^;|&]*-exec'; } &&
  has 'rm[[:space:]]' &&
  has '(^|[[:space:]])-[a-z]*r|--recursive' &&
  has '(^|[[:space:]])-[a-z]*f|--force'; then
  block "wrapped rm with recursive+force (sh -c / xargs / find -exec / ...)."
fi

# credential files via shell readers. the Read() deny rules in settings.json
# only cover file tools, this closes the `cat ~/.ssh/...` side. ssh/scp/git
# stay usable, only content readers are blocked.
readers='(cat|bat|less|more|head|tail|strings|base64|xxd|od|hexdump|grep|rg|awk|sed)'
secretpaths='(~|\$HOME|/Users/[^/[:space:]]+)/\.(ssh/|aws/|gnupg/|kube/|config/sops/|docker/config\.json|git-credentials)'
has "(^|[;&|][[:space:]]*)${readers}[[:space:]][^;|&]*${secretpaths}" &&
  block "reading credential files via shell. those paths are off limits."
if has "(^|[;&|][[:space:]]*)${readers}[[:space:]]([^;|&]*[[:space:]])?[^;|&[:space:]]*\.env(\.[A-Za-z0-9_-]+)?([[:space:]]|$)" &&
  ! has '\.env\.(example|sample|template|dist)'; then
  block ".env files hold secrets. templates (.env.example etc) are fine to read."
fi

# device level / fork bomb
has '(^|[;&|][[:space:]]*)dd[[:space:]]+[^;|&]*of=/dev/(disk|rdisk|sd|nvme)' &&
  block "dd onto a block device."
has ':\(\)[[:space:]]*\{[[:space:]]*:\|:' &&
  block "fork bomb."

exit 0
