#!/usr/bin/env bash
# patterns borrowed with thanks from github.com/AnastasiyaW/claude-code-config
set -euo pipefail

block() {
  echo "BLOCKED by bash-guard: $1" >&2
  exit 2
}

json="$(cat)"
cmd="$(jq -r '.tool_input.command // empty' <<<"$json")" ||
  block "unreadable hook input. the guard does not let through what it cannot parse."
[ -z "$cmd" ] && exit 0

cmd="${cmd//\\$'\n'/ }"
cmd="${cmd//$'\n'/; }"

scan="$cmd"$'\n'"${cmd//[\'\"]/}"

has() { grep -qiE "$1" <<<"$scan"; }
hasC() { grep -qE "$1" <<<"$scan"; } # case sensitive, for -D vs -d style flags

end='([[:space:];|&`)]|$)'

gitopt='(-[Cc][[:space:]]+("[^"]*"|[^[:space:];|&]+)|--[a-z-]+(=[^[:space:];|&]+)?|-[pP])'
gitpre="git([[:space:]]+${gitopt})*[[:space:]]+"

nomsg="$(sed -E 's/(-[a-zA-Z]*m|--message=?)[[:space:]]*("[^"]*"|'"'"'[^'"'"']*'"'"')/\1 _/g' <<<"$cmd")"
grep -qiE "${gitpre}push${end}" <<<"$nomsg"$'\n'"${nomsg//[\'\"]/}" &&
  block "git push. pushing is the user's call, always."
bare="$(sed -E 's/"([^" ]*)"/\1/g; s/"[^"]*"//g' <<<"$cmd" |
  sed -E "s/'([^' ]*)'/\1/g; s/'[^']*'//g")"
grep -qE "${gitpre}add[^;|&]*([^-]-[a-zA-Z]*A[a-zA-Z]*|[[:space:]]--all)${end}" <<<"$bare" &&
  block "git add -A stages everything in the tree. name the paths of this change."
grep -qE "${gitpre}add[[:space:]]+([^;|&]*[[:space:]])?(--[[:space:]]+)?\.${end}" <<<"$bare" &&
  block "git add . stages everything below the cwd. name the paths of this change."
grep -qE "${gitpre}commit[^;|&]*([^-]-[a-z]*a[a-z]*|[[:space:]]--all)${end}" <<<"$bare" &&
  block "git commit -a stages every tracked change. stage the paths you mean, then commit."
has "${gitpre}(filter-branch|reflog[[:space:]]+expire|gc[[:space:]]+[^;|&]*--prune=now)" &&
  block "git history rewrite/expire."
has 'git[[:space:]][^;|&]*--no-(verify|hooks|pre-commit-hook)' &&
  block "bypassing git hooks (--no-verify). fix what the hook complains about."
grep -qE "${gitpre}commit[^;|&]*[^-]-[a-z]*n[a-z]*${end}" <<<"$bare" &&
  block "git commit -n is the short form of --no-verify. fix what the hook complains about."

has "kubectl[[:space:]]+delete[[:space:]]+(ns|namespaces?)([[:space:]/]|$)" &&
  block "kubectl delete namespace."
has "kubectl[[:space:]]+delete[[:space:]]+[^;|&]*--all${end}" &&
  block "kubectl delete --all."
has 'docker[[:space:]]+system[[:space:]]+prune[[:space:]]+[^;|&]*(-[a-z]*a|--volumes)' &&
  block "docker system prune -a/--volumes."

has "skills[[:space:]]+(add|install|i|a|remove|rm|update|upgrade)[[:space:]][^;|&]*(-[a-z]*g|--global)${end}" &&
  block "global skill install. skills live in nix-config (home/cli/claude/default.nix), declare it there."

has 'claude[[:space:]]+plugins?[[:space:]]+(install|i|add|marketplace|update|enable)' &&
  block "plugin install. this setup runs no plugins, declare the skill, agent or lspServers entry in home/cli/claude instead."

has ':\(\)[[:space:]]*\{[[:space:]]*:\|:' &&
  block "fork bomb."

out="$nomsg"$'\n'"${nomsg//[\'\"]/}"
hasO() { grep -qiE "$1" <<<"$out"; }

outF="$(sed -E 's/(gh|glab|tea|hub)([[:space:]]+)(alias|config)[[:space:]]/\1\2_ /g' <<<"$out")"
forgeverb='(create|new|comment|edit|delete|close|reopen|merge|review|approve|ready|publish|upload|transfer|rename|pin|lock|dispatch|sync|set|add|fork)'
grep -qiE "(^|[^a-z0-9_-])(gh|glab|tea|hub)[[:space:]]+[a-z-]+[[:space:]]+${forgeverb}${end}" <<<"$outF" &&
  block "posting to a forge. PRs, issues, comments, releases are the user's to send, never yours."
hasO "(^|[^a-z0-9_-])hub[[:space:]]+(pull-request|fork|create)${end}" &&
  block "posting to a forge. PRs, issues, comments, releases are the user's to send, never yours."

ghapi="(^|[^a-z0-9_-])(gh|glab)[[:space:]]+api[[:space:]]"
method="(-X|--method)[[:space:]]*=?[[:space:]]*"
hasO "${ghapi}[^;|&]*${method}(POST|PUT|PATCH|DELETE)" &&
  block "gh api with a write method. reading the api is fine, writing is not."
if hasO "$ghapi" && ! hasO "${method}GET" &&
  hasO "${ghapi}([^;|&]*[[:space:]])?(-f|-F|--field|--raw-field|--input)([[:space:]]|=)"; then
  block "gh api with fields defaults to POST. add --method GET if you meant to read."
fi

projhosts() {
  local d
  d="$(jq -r '.cwd // empty' <<<"$json")"
  while [ -n "$d" ] && [ "$d" != "/" ]; do
    if [ -f "$d/.claude/$1" ]; then
      tr '[:upper:]' '[:lower:]' <"$d/.claude/$1" |
        grep -vE '^[[:space:]]*(#|$)' | sed 's/\./\\./g' | paste -sd '|' - || true
      return
    fi
    d="$(dirname "$d")"
  done
}
localhosts='localhost|127\.[0-9]+\.[0-9]+\.[0-9]+|\[?::1\]?|0\.0\.0\.0|host\.docker\.internal|[a-z0-9.-]+\.(test|localhost)'
okhosts="$localhosts"
extra="$(projhosts outbound-hosts)"
[ -n "$extra" ] && okhosts="$okhosts|$extra"

# every real target must be listed, a listed name elsewhere in the line unlocks nothing
hostok() { # $1 allowed pattern, $2 [user@]host[:port][/path] or url
  local h
  h="$(tr '[:upper:]' '[:lower:]' <<<"$2")"
  h="${h#*://}"
  h="${h##*@}"
  if [[ "$h" == \[* ]]; then h="${h%%]*}]"; else h="${h%%[:/?#]*}"; fi
  [ -n "$h" ] && grep -qxE "($1)" <<<"$h"
}
segments() { tr ';|&()`' '\n\n\n\n\n ' <<<"$1"; }
# a listed host is allowed, not approved. ask rules miss a wrapped or absolute call
asks=""
listed() { hostok "$1" "$2" && { hostok "$localhosts" "$2" || asks="$asks $2"; }; }

# an unknown option value is taken as a host and fails, so unknown ends in a block
localWrite() {
  local u line seg found=0 i o tool
  while IFS= read -r u; do
    listed "$okhosts" "$u" || return 1
    found=1
  done < <(grep -oiE "https?://[^[:space:]\"'/]+" <<<"$out")
  seg="$(segments "$(sed -E 's/"([^" ]*)"/\1/g; s/"[^"]*"/_/g' <<<"$nomsg" |
    sed -E "s/'([^' ]*)'/\1/g; s/'[^']*'/_/g")")"
  while IFS= read -r line; do
    read -ra t <<<"$line"
    tool=""
    for ((i = 0; i < ${#t[@]}; i++)); do
      case "$(tr '[:upper:]' '[:lower:]' <<<"${t[i]##*/}")" in
        curl | wget | http | https | xh | xhs) tool="${t[i]##*/}" && break ;;
      esac
    done
    [ -z "$tool" ] && continue
    for ((i = i + 1; i < ${#t[@]}; i++)); do
      o="${t[i]}"
      case "$o" in
        -K | --config | --config=* | --resolve* | --connect-to*) return 1 ;;
        --data | --data-* | --form | --form-string | --upload-file | --header | --output | --output-document | \
          --user | --cookie | --cookie-jar | --user-agent | --referer | --write-out | --request | --method | \
          --max-time | --connect-timeout | --json | --post-data | --post-file | --body-data | --body-file | --auth)
          i=$((i + 1)) ;;
        --*) ;;
        -*) [[ "${o: -1}" == [dFTHouAbcewXmrzCDaO] ]] && i=$((i + 1)) ;;
        @* | *=* | GET | POST | PUT | PATCH | DELETE | HEAD | OPTIONS) ;;
        :*) found=1 ;; # httpie shorthand for localhost
        *)
          listed "$okhosts" "$o" || return 1
          found=1
          # httpie/xh: request items follow the url
          [[ "$tool" == http* || "$tool" == xh* ]] && break
          ;;
      esac
    done
  done <<<"$seg"
  [ "$found" = 1 ]
}

httpverb='(^|[^a-z0-9_-])(curl|wget)[[:space:]][^;|&]*((-X|--request|--method)[[:space:]]*=?[[:space:]]*(POST|PUT|PATCH|DELETE)|--data|--form|--upload-file|--json|--post-data|--post-file|--body-data|--body-file)'
curlbody='(^|[^a-z0-9_-])curl[[:space:]]+([^;|&]*[[:space:]])?-[a-zA-Z]*[dFT]([[:space:]]|=|@|$)'
httpie='(^|[^a-z0-9_-])(http|xh)[[:space:]]+([^;|&]*[[:space:]])?(POST|PUT|PATCH|DELETE)([[:space:]]|$)'
if localWrite; then
  hasO "$httpverb" || grep -qE "$curlbody|$httpie" <<<"$out" || asks=""
else
  hasO "$httpverb" &&
    block "an http write (POST/PUT/PATCH/DELETE or a body). reading a url is fine, writing to one is not."
  grep -qE "$curlbody" <<<"$out" &&
    block "curl -d/-F/-T sends a body. reading a url is fine, writing to one is not."
  grep -qE "$httpie" <<<"$out" &&
    block "an http write (POST/PUT/PATCH/DELETE or a body). reading a url is fine, writing to one is not."
  asks=""
fi

sshok="$localhosts"
extra="$(projhosts ssh-hosts)"
[ -n "$extra" ] && sshok="$sshok|$extra"
remote() {
  block "a remote shell or transfer (ssh/scp/rsync/ftp) $1. other machines are off limits, the user lists exceptions in .claude/ssh-hosts."
}
# leaves $i on the first operand. -F and HostName/ProxyCommand redirect a listed name
sshopts() { # $1 option letters that take a value
  local o c v k j
  while [ "$i" -lt "${#t[@]}" ]; do
    o="${t[i]}"
    case "$o" in
      --) i=$((i + 1)) && return 0 ;;
      --*) i=$((i + 1)) && continue ;;
      -?*) ;;
      *) return 0 ;;
    esac
    for ((k = 1; k < ${#o}; k++)); do
      c="${o:k:1}"
      [[ "$1" == *"$c"* ]] || continue
      v="${o:k+1}"
      [ -z "$v" ] && i=$((i + 1)) && v="${t[i]-}"
      case "$c" in
        F) remote "with -F, a config file can send a listed name anywhere" ;;
        J) IFS=, read -ra j <<<"$v" && for v in "${j[@]}"; do listed "$sshok" "$v" || remote "via jump host $v"; done ;;
        o)
          case "$(tr '[:upper:]' '[:lower:]' <<<"$v")" in
            proxyjump=*) IFS=, read -ra j <<<"${v#*=}" && for v in "${j[@]}"; do listed "$sshok" "$v" || remote "via jump host $v"; done ;;
            hostname* | proxycommand* | proxyjump* | include* | localcommand* | permitlocalcommand*)
              remote "with -o $v, it can send a listed name anywhere" ;;
          esac
          ;;
      esac
      break
    done
    i=$((i + 1))
  done
}
# the tool as last word is no call (man page), except behind xargs. after the
# host only the head of the remote command counts
remoteCheck() {
  local tool
  i=0
  while [ "$i" -lt "${#t[@]}" ]; do
    tool="$(tr '[:upper:]' '[:lower:]' <<<"${t[i]##*/}")"
    case "$tool" in
      ssh | autossh | mosh | sftp | scp | rsync | ftp | lftp | ncftp | tnftp) ;;
      *) i=$((i + 1)) && continue ;;
    esac
    if [ $((i + 1)) -ge "${#t[@]}" ]; then
      [[ " ${t[*]} " == *" xargs "* || " ${t[*]} " == *" parallel "* ]] && remote "with hosts from stdin"
      return 0
    fi
    i=$((i + 1))
    case "$tool" in
      ssh | autossh | mosh | sftp)
        case "$tool" in
          ssh) sshopts BbcDEeFIiJLlmOoPpQRSWw ;;
          autossh) sshopts BbcDEeFIiJLlMmOoPpQRSWw ;;
          mosh) sshopts p ;;
          sftp) sshopts BbcDFiJloPRSX ;;
        esac
        [ "$i" -lt "${#t[@]}" ] || remote "without a readable target"
        listed "$sshok" "${t[i]}" || remote "to ${t[i]}"
        [ "$tool" = sftp ] && return 0
        i=$((i + 1))
        while [[ "${t[i]-}" =~ ^(sudo|env|exec|command|nohup|--)$ ]]; do i=$((i + 1)); done
        [[ "$(tr '[:upper:]' '[:lower:]' <<<"${t[i]-}")" =~ ^(.*/)?(ssh|autossh|mosh|sftp|scp|rsync|ftp|lftp|ncftp|tnftp)$ ]] || return 0
        ;;
      scp | rsync)
        [ "$tool" = scp ] && sshopts cFiJloPSX
        for ((; i < ${#t[@]}; i++)); do
          if [[ "${t[i]##*/}" == ssh || "${t[i]}" == *=ssh ]]; then
            i=$((i + 1)) && sshopts BbcDEeFIiJLlmOoPpQRSWw
          fi
          [[ "${t[i]-}" == -* ]] && continue
          [[ "${t[i]-}" == *://* || "${t[i]-}" =~ ^[^/]+: ]] || continue
          listed "$sshok" "${t[i]}" || remote "to ${t[i]}"
        done
        return 0
        ;;
      *)
        for ((; i < ${#t[@]}; i++)); do
          [[ "${t[i]}" == -* || "${t[i]}" =~ ^[0-9]+$ ]] && continue
          listed "$sshok" "${t[i]}" || remote "to ${t[i]}"
        done
        return 0
        ;;
    esac
  done
}
while IFS= read -r line; do
  read -ra t <<<"$line"
  remoteCheck
done <<<"$(segments "${nomsg//[\'\"]/}")"

hasO '(^|[^a-z0-9_-])(npm|pnpm|yarn|bun|deno|cargo|uv|poetry|flit|maturin|hatch)[[:space:]]+publish' &&
  block "publishing a package. what leaves this machine is the user's call."
hasO '(^|[^a-z0-9_-])((gem|helm|oras|ko|cachix|attic)[[:space:]]+push|twine[[:space:]]+upload|goreleaser[[:space:]]+release|mix[[:space:]]+hex\.publish)' &&
  block "publishing a package. what leaves this machine is the user's call."
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
hasO 'osascript[^;|&]*(Mail|Messages)[^;|&]*[[:space:]]send([[:space:]]|$)' &&
  block "sending mail or a message via applescript. that is the user's to send."
hasO "${gitpre}send-email" &&
  block "git send-email. patches leave this machine through the user, not you."

# these files widen what the guard lets through, so only reading them is open
while IFS= read -r line; do
  grep -qE '\.claude/(ssh-hosts|outbound-hosts|settings(\.local)?\.json)' <<<"$line" || continue
  [[ "$line" != *">"* ]] &&
    grep -qE '^[[:space:]]*(cat|head|tail|less|grep|rg|wc|jq|ls|stat|diff|git[[:space:]]+(diff|log|show|blame|status))([[:space:]]|$)' <<<"$line" &&
    continue
  block "writing .claude/ssh-hosts, outbound-hosts or project settings. the user maintains those."
done <<<"$(segments "${nomsg//[\'\"]/}")"

if [ -n "$asks" ]; then
  jq -n --arg r "reaches$asks. a listed host still needs the user's ok for every call." \
    '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "ask", permissionDecisionReason: $r}}'
fi
exit 0
