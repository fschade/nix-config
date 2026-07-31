#!/usr/bin/env bash
# claude code PreToolUse guard for Bash. blocks destructive and outward-facing
# command shapes that plain deny globs cant catch (flag permutations, compound
# commands, sh -c wrappers. we scan the whole command string, so wrapped
# one-liners match too).
# input: tool call json on stdin. block: message on stderr + exit 2.
#
# patterns borrowed with thanks from:
#   github.com/trailofbits/claude-code-config (rm flag permutations, pipe-to-shell)
#   github.com/AnastasiyaW/claude-code-config (destructive git/k8s, secret readers)
#   github.com/davila7/claude-code-templates (interpreter wrapper idea)
# trimmed and rewritten for this setup.
set -euo pipefail

block() {
  echo "BLOCKED by bash-guard: $1" >&2
  exit 2
}

# every exit code except 2 lets the call through, so a payload we cannot read has
# to end in a block: no command parsed means no command checked. an empty payload
# is a different thing, there is simply nothing in it to check. the payload is
# kept whole, the outward rules below also need its cwd.
json="$(cat)"
cmd="$(jq -r '.tool_input.command // empty' <<<"$json")" ||
  block "unreadable hook input. the guard does not let through what it cannot parse."
[ -z "$cmd" ] && exit 0

# grep works line by line, so a command split over several lines slips past
# every rule whose pattern spans more than one token: `git \<newline>push` was
# not a push. a continuation joins two tokens, so it becomes a space. a plain
# newline separates two commands, so it becomes the separator the anchors below
# already accept, not a space, or `rm` on its own line would stop being anchored.
cmd="${cmd//\\$'\n'/ }"
cmd="${cmd//$'\n'/; }"

# quoting the command name defeats every rule below: `'rm' -rf` has no word
# boundary after rm, `"kubectl" delete ns` none before it. so scan a
# quote-stripped copy too. grep is line based and no pattern spans lines, so
# appending it as a second line means "matches either form": the stripped copy
# catches the quoted spelling, the raw one keeps the rules that need the quotes
# (git -C "a b" push, cat ".env").
scan="$cmd"$'\n'"${cmd//[\'\"]/}"

has() { grep -qiE "$1" <<<"$scan"; }
hasC() { grep -qE "$1" <<<"$scan"; } # case sensitive, for -D vs -d style flags

# what ends a word for the rules that need to see the end of one. a separator
# ends it just like a space or the line end does: `then git push; fi` and
# `do kubectl delete pods --all; done` have nothing but the `;` after the token.
# a closing command-substitution backtick counts too, or a token pressed against
# it (echo backtick-git push-backtick) slips every rule that uses this class.
end='([[:space:];|&`)]|$)'

# rm with recursive+force in any flag spelling. rm is matched as a word, not
# anchored on a separator: an anchor misses everything with something in front,
# `sudo rm`, `then rm`, `do rm`, `(rm ...)` and every wrapper (sh -c "rm ...",
# xargs, find -exec). false positives on unrelated flags in compound commands
# are fine: split the command or delete without -f.
if has '(^|[^a-z0-9_-])rm[[:space:]]' &&
  has '(^|[[:space:]])-[a-z]*r|--recursive' &&
  has '(^|[[:space:]])-[a-z]*f|--force'; then
  block "rm with recursive+force. delete precisely (no -f) or leave it to the user."
fi

# push has a deny rule in settings too, but that one matches the whole command
# string, so `cd repo && git push` walks past it. never-push is the hardest rule
# in CLAUDE.md, so it gets its own here.
#
# only git's own options may sit between `git` and the subcommand. every git rule
# below goes through this chain, or `git -C dir reset --hard` walks past a rule
# that expects the subcommand glued to `git`. a subcommand breaks the chain,
# which is what tells `git -C dir push` from a `git ... commit -m` about pushing.
gitopt='(-[Cc][[:space:]]+("[^"]*"|[^[:space:];|&]+)|--[a-z-]+(=[^[:space:];|&]+)?|-[pP])'
gitpre="git([[:space:]]+${gitopt})*[[:space:]]+"

# a -m message is prose, not a command: `git commit -m "docs: explain git push
# flow"` is not a push. so blank the message argument out for this rule. it is
# the one git rule that still has to see quoted spans (`git "push"`,
# sh -c "git push"), so it cannot use the `bare` copy below.
nomsg="$(sed -E 's/(-[a-zA-Z]*m|--message=?)[[:space:]]*("[^"]*"|'"'"'[^'"'"']*'"'"')/\1 _/g' <<<"$cmd")"
grep -qiE "${gitpre}push${end}" <<<"$nomsg"$'\n'"${nomsg//[\'\"]/}" &&
  block "git push. pushing is the user's call, always."
hasC "${gitpre}branch[[:space:]]+(-[a-zA-Z]*D|--delete[[:space:]]+--force|--force[[:space:]]+--delete)" &&
  block "git branch -D. use -d or let the user force it."
has "${gitpre}clean[[:space:]]+[^;|&]*-[a-z]*f" &&
  block "git clean -f. untracked files are not yours to bulk delete."
has "${gitpre}(checkout|restore)[[:space:]]+([^;|&]*[[:space:]])?(--[[:space:]]+)?\.${end}" &&
  block "mass discard of working tree changes."
has "${gitpre}reset[[:space:]]+[^;|&]*--hard" &&
  block "git reset --hard."
# a blanket stage takes whatever else is in the tree with it, including another
# session's half-finished work. naming the paths is also the only way the commit
# ends up being what its message says.
#
# these three scan a copy with quoted spans dropped: a commit message may talk
# about `git add -A` or `--all` without being one, and that message is exactly
# what gets written when this rule fires. but dropping every quoted span also
# drops a quoted command name (`"git" add -A`), which then walks past every rule.
# so unquote the single-token quoted words first (no space inside), and only
# then drop the remaining multi-word spans, which is where the messages live.
bare="$(sed -E 's/"([^" ]*)"/\1/g; s/"[^"]*"//g' <<<"$cmd" |
  sed -E "s/'([^' ]*)'/\1/g; s/'[^']*'//g")"
grep -qE "${gitpre}add[^;|&]*([^-]-[a-zA-Z]*A[a-zA-Z]*|[[:space:]]--all)${end}" <<<"$bare" &&
  block "git add -A stages everything in the tree. name the paths of this change."
grep -qE "${gitpre}add[[:space:]]+([^;|&]*[[:space:]])?(--[[:space:]]+)?\.${end}" <<<"$bare" &&
  block "git add . stages everything below the cwd. name the paths of this change."
# the short form needs a non-dash in front of its dash, so `--amend`, `--author`
# and `--allow-empty` stay allowed. blocking an amend would be absurd, and this
# rule blocked one within a minute of being written.
grep -qE "${gitpre}commit[^;|&]*([^-]-[a-z]*a[a-z]*|[[:space:]]--all)${end}" <<<"$bare" &&
  block "git commit -a stages every tracked change. stage the paths you mean, then commit."
has "${gitpre}(filter-branch|reflog[[:space:]]+expire|gc[[:space:]]+[^;|&]*--prune=now)" &&
  block "git history rewrite/expire."
# two independent configs converged on this one: harperreed/dotfiles and
# jbarbier/CLAUDE.md, thanks.
has 'git[[:space:]][^;|&]*--no-(verify|hooks|pre-commit-hook)' &&
  block "bypassing git hooks (--no-verify). fix what the hook complains about."
# -n is git's own short form of --no-verify, but only on commit: `git clean -n`
# is a dry run and `grep -n` is line numbers. reads the quoted-span-free copy,
# a commit message may talk about some -n flag without being one.
grep -qE "${gitpre}commit[^;|&]*[^-]-[a-z]*n[a-z]*${end}" <<<"$bare" &&
  block "git commit -n is the short form of --no-verify. fix what the hook complains about."

has "kubectl[[:space:]]+delete[[:space:]]+(ns|namespaces?)([[:space:]/]|$)" &&
  block "kubectl delete namespace."
has "kubectl[[:space:]]+delete[[:space:]]+[^;|&]*--all${end}" &&
  block "kubectl delete --all."
has 'docker[[:space:]]+system[[:space:]]+prune[[:space:]]+[^;|&]*(-[a-z]*a|--volumes)' &&
  block "docker system prune -a/--volumes."

# pipe from the internet straight into a shell, also via sudo and with a
# filter in between (curl ... | tee f | sh)
has "(curl|wget)[[:space:]][^;&]*\|[[:space:]]*(sudo[[:space:]]+)?(ba|z|da|fi)?sh${end}" &&
  block "piping a download into a shell. download, inspect, then run."

# the Read() deny rules in settings.json only cover the file tools, this closes
# the `cat ~/.ssh/...` side. ssh/scp/git stay usable, only readers are blocked.
#
# the reader is matched as a word, like rm above: anchoring on a separator let
# every wrapped form past, `sudo cat`, `echo $(cat ...)`, `xargs cat`, a cat
# inside a then/do block. both rules need a reader AND a secret path in the same
# line, so the loose match costs little.
readers='(cat|bat|less|more|head|tail|strings|base64|xxd|od|hexdump|grep|rg|awk|sed)'
secretpaths='(~|\$HOME|/Users/[^/[:space:]]+)/(\.(ssh/|aws/|gnupg/|kube/|config/sops/|config/gh/|docker/config\.json|git-credentials|npmrc)|Library/Keychains/)'
has "(^|[^a-z0-9_-])${readers}[[:space:]][^;|&]*${secretpaths}" &&
  block "reading credential files via shell. those paths are off limits."
# the exception belongs to a name, not to the command: naming a template next to
# the real file (`cat .env .env.example`) must not unlock it. so drop the
# template names first, whatever `.env` is left is the one with the secrets.
#
# the name ends at anything that cant be part of it, not just whitespace: a
# closing quote (`cat ".env"`) or a paren (`echo $(cat .env)`) end it too, while
# a letter does not, so .envrc stays readable.
envscan="$(sed -E 's/\.env\.(example|sample|template|dist)([^A-Za-z0-9_.-]|$)/\2/g' <<<"$scan")"
grep -qiE "(^|[^a-z0-9_-])${readers}[[:space:]]([^;|&]*[[:space:]])?[^;|&[:space:]]*\.env(\.[A-Za-z0-9_-]+)?([^A-Za-z0-9_.-]|$)" <<<"$envscan" &&
  block ".env files hold secrets. templates (.env.example etc) are fine to read."

# global agent skills are declared in nix-config (home/cli/claude), and both
# ~/.agents and ~/.claude/skills are read-only store paths, so a global install
# would fail anyway, this just says why. project scope stays fine.
has "skills[[:space:]]+(add|install|i|a|remove|rm|update|upgrade)[[:space:]][^;|&]*(-[a-z]*g|--global)${end}" &&
  block "global skill install. skills live in nix-config (home/cli/claude/default.nix), declare it there."

# same for plugins, we run none. ~/.claude/plugins is an empty read-only store
# path and the official marketplace autoinstall is off. an lsp goes into
# settings.json under lspServers, anything else into skills/ or agents/.
has 'claude[[:space:]]+plugins?[[:space:]]+(install|i|add|marketplace|update|enable)' &&
  block "plugin install. this setup runs no plugins, declare the skill, agent or lspServers entry in home/cli/claude instead."

# dd matched as a word, like rm: a separator anchor let `sudo dd`, `then dd` and
# `xargs dd` past. the char before dd must not be one that could belong to a name
# (`add`, an odd path), so a space, a separator or the line start.
has '(^|[^a-z0-9_/.-])dd[[:space:]]+[^;|&]*of=/dev/(disk|rdisk|sd|nvme)' &&
  block "dd onto a block device."
has ':\(\)[[:space:]]*\{[[:space:]]*:\|:' &&
  block "fork bomb."

# nothing goes outward. these shapes are not destructive, they are public: a PR,
# an issue, a comment, a release, a published package, a mail. sending one is
# the user's, never ours, same deal as push.
#
# they read the message-blanked copy the push rule builds, so `git commit -m
# "docs: how to gh pr create"` stays prose. quoted spans are still in it, a
# wrapped `sh -c "gh pr create"` is still a create.
out="$nomsg"$'\n'"${nomsg//[\'\"]/}"
hasO() { grep -qiE "$1" <<<"$out"; }

# forge clis: object plus write verb, glued together in that order. the read
# side (`gh pr list`, `gh issue view`, `glab mr diff`) keeps working, and a verb
# that only appears in an argument (`gh pr list --state closed`) is not a write.
# alias/config are local, not the forge, so their object gets blanked before
# the verb rule looks: `gh alias set` and `gh config set` stay usable. `run`
# and `rerun` are not in the verb list, triggering the user's own ci (`gh
# workflow run`, `gh run rerun`) is not posting.
outF="$(sed -E 's/(gh|glab|tea|hub)([[:space:]]+)(alias|config)[[:space:]]/\1\2_ /g' <<<"$out")"
forgeverb='(create|new|comment|edit|delete|close|reopen|merge|review|approve|ready|publish|upload|transfer|rename|pin|lock|dispatch|sync|set|add|fork)'
grep -qiE "(^|[^a-z0-9_-])(gh|glab|tea|hub)[[:space:]]+[a-z-]+[[:space:]]+${forgeverb}${end}" <<<"$outF" &&
  block "posting to a forge. PRs, issues, comments, releases are the user's to send, never yours."
# hub skips the object, `hub pull-request` opens one on its own
hasO "(^|[^a-z0-9_-])hub[[:space:]]+(pull-request|fork|create)${end}" &&
  block "posting to a forge. PRs, issues, comments, releases are the user's to send, never yours."

# the api is the way around every rule above, so it gets the same treatment
ghapi="(^|[^a-z0-9_-])(gh|glab)[[:space:]]+api[[:space:]]"
method="(-X|--method)[[:space:]]*=?[[:space:]]*"
hasO "${ghapi}[^;|&]*${method}(POST|PUT|PATCH|DELETE)" &&
  block "gh api with a write method. reading the api is fine, writing is not."
# a field flips gh api to POST by itself (`gh api --help` says so), so the read
# form of a graphql query has to spell out --method GET.
if hasO "$ghapi" && ! hasO "${method}GET" &&
  hasO "${ghapi}([^;|&]*[[:space:]])?(-f|-F|--field|--raw-field|--input)([[:space:]]|=)"; then
  block "gh api with fields defaults to POST. add --method GET if you meant to read."
fi

# a write to a dev host is api testing, not posting: localhost, loopback,
# docker's name for the host machine, the tlds reserved for local use (.test,
# .localhost, rfc 6761). a project widens this with .claude/outbound-hosts at
# its root, one host per line, # comments and blanks skipped, found by walking
# up from the payload cwd. project settings.json cant do it, an allow rule
# never overrides a blocking hook.
#
# the check is textual and guards intent, not an adversary: the command must
# name an allowed host and no scheme url to anywhere else. a bare remote
# domain sitting next to a local url slips.
okhosts='localhost|127\.[0-9]+\.[0-9]+\.[0-9]+|\[?::1\]?|0\.0\.0\.0|host\.docker\.internal|[a-z0-9.-]+\.(test|localhost)'
d="$(jq -r '.cwd // empty' <<<"$json")"
while [ -n "$d" ] && [ "$d" != "/" ]; do
  if [ -f "$d/.claude/outbound-hosts" ]; then
    hosts="$(tr '[:upper:]' '[:lower:]' <"$d/.claude/outbound-hosts" |
      grep -vE '^[[:space:]]*(#|$)' | sed 's/\./\\./g' | paste -sd '|' - || true)"
    [ -n "$hosts" ] && okhosts="$okhosts|$hosts"
    break
  fi
  d="$(dirname "$d")"
done
localWrite() {
  local low
  low="$(tr '[:upper:]' '[:lower:]' <<<"$out")"
  # an allowed host must be named as a target, not buried in a longer name:
  # something url-ish in front (start, space, quote, =, @, ://), a port, path
  # or end behind. `localhost.example.com` matches neither side.
  grep -qE "(^|[[:space:]\"'=@]|://)(${okhosts})([:/[:space:]\"']|$)" <<<"$low" || return 1
  # then drop every allowed scheme url and see if a scheme to somewhere else
  # remains. the boundary char after the host is consumed on purpose: without
  # it the sed eats `http://localhost` out of `http://localhost.example.com`
  # and the leftover no longer looks like a url.
  ! sed -E "s#https?://(${okhosts})(:[0-9]+)?([/[:space:]\"']|\$)##g" <<<"$low" | grep -qE 'https?://'
}

# http clients writing. GET stays open, a body or a write method does not,
# unless every named target is a dev host (okhosts above).
if ! localWrite; then
  hasO '(^|[^a-z0-9_-])(curl|wget)[[:space:]][^;|&]*((-X|--request|--method)[[:space:]]*=?[[:space:]]*(POST|PUT|PATCH|DELETE)|--data|--form|--upload-file|--json|--post-data|--post-file|--body-data|--body-file)' &&
    block "an http write (POST/PUT/PATCH/DELETE or a body). reading a url is fine, writing to one is not."
  # curls short flags are case sensitive: -d -F -T write, -f -t do not. matched
  # inside a bundle too, `curl -sd @payload` is a POST.
  grep -qE '(^|[^a-z0-9_-])curl[[:space:]]+([^;|&]*[[:space:]])?-[a-zA-Z]*[dFT]([[:space:]]|=|@|$)' <<<"$out" &&
    block "curl -d/-F/-T sends a body. reading a url is fine, writing to one is not."
  # httpie/xh take the method as a bare word. matched case sensitive, or a url
  # path ending in /post reads as one.
  grep -qE '(^|[^a-z0-9_-])(http|xh)[[:space:]]+([^;|&]*[[:space:]])?(POST|PUT|PATCH|DELETE)([[:space:]]|$)' <<<"$out" &&
    block "an http write (POST/PUT/PATCH/DELETE or a body). reading a url is fine, writing to one is not."
fi

hasO '(^|[^a-z0-9_-])(npm|pnpm|yarn|bun|deno|cargo|uv|poetry|flit|maturin|hatch)[[:space:]]+publish' &&
  block "publishing a package. what leaves this machine is the user's call."
hasO '(^|[^a-z0-9_-])((gem|helm|oras|ko|cachix|attic)[[:space:]]+push|twine[[:space:]]+upload|goreleaser[[:space:]]+release|mix[[:space:]]+hex\.publish)' &&
  block "publishing a package. what leaves this machine is the user's call."
# covers `docker buildx build --push` along with the plain push
hasO '(^|[^a-z0-9_-])(docker|podman|nerdctl|buildah)[[:space:]]+([^;|&]*[[:space:]])?(--)?push([[:space:]=]|$|[;|&])' &&
  block "pushing an image to a registry. what leaves this machine is the user's call."
hasO 'nix[[:space:]]+copy[[:space:]][^;|&]*--to' &&
  block "nix copy to a remote store. what leaves this machine is the user's call."
hasO 'brew[[:space:]]+bump-(formula|cask)-pr' &&
  block "brew bump-*-pr opens a PR upstream. that is the user's to send."

hasO '(^|[^a-z0-9_/.-])(sendmail|msmtp|mailx|swaks|mutt|neomutt)[[:space:]]' &&
  block "sending mail. writing the draft to a file is fine, sending it is the user's."
hasO '(^|[^a-z0-9_/.-])mail[[:space:]]+[^;|&]*-s[[:space:]]' &&
  block "sending mail. writing the draft to a file is fine, sending it is the user's."
# the applescript route to Mail and Messages, which no other rule here sees
hasO 'osascript[^;|&]*(Mail|Messages)[^;|&]*[[:space:]]send([[:space:]]|$)' &&
  block "sending mail or a message via applescript. that is the user's to send."
hasO "${gitpre}send-email" &&
  block "git send-email. patches leave this machine through the user, not you."

exit 0
