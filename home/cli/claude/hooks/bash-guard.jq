# rules behind bash-guard.sh, input is shfmt's --to-json tree, output one "kind<TAB>text" line per finding
def part($dq):
  if .Type == "Lit" then
    if $dq then .Value | gsub("\\\\(?<c>[$`\"\\\\])"; .c) else .Value | gsub("\\\\(?<c>.)"; .c) end
  elif .Type == "SglQuoted" then .Value
  elif .Type == "DblQuoted" then [.Parts[]? | part(true)] | join("")
  else "$" end;
def word: [.Parts[]? | part(false)] | join("");
def name: sub(".*/"; "") | ascii_downcase;
def has_($x): any(.[]; . == $x);
def after($x): (indices($x) | first) as $i | if $i == null then [] else .[$i + 1:] end;

def strip($valopts):
  if length > 0 and (.[0] | startswith("-")) then
    .[0] as $t | (if $valopts | has_($t) then .[2:] else .[1:] end) | strip($valopts)
  else . end;
def assigns: if length > 0 and (.[0] | test("^[A-Za-z_][A-Za-z0-9_]*=")) then .[1:] | assigns else . end;
# wrappers that run the rest of their argv as a command
def unwrap:
  if length == 0 then . else
    (.[0] | name) as $c
    | if $c == "sudo" or $c == "doas" then .[1:] | strip(["-u", "-g", "-C", "-D", "-h", "-p", "-r", "-t", "-U"]) | unwrap
      elif $c == "env" then .[1:] | strip(["-u", "-C", "-S", "-P"]) | assigns | unwrap
      elif $c == "xargs" then .[1:] | strip(["-I", "-n", "-P", "-L", "-d", "-E", "-s", "-a"]) | unwrap
      elif $c == "nice" then .[1:] | strip(["-n"]) | unwrap
      elif $c == "timeout" then .[1:] | strip(["-s", "-k", "--signal", "--kill-after"]) | .[1:] | unwrap
      elif ["command", "exec", "nohup", "time", "builtin", "rtk", "caffeinate"] | has_($c) then .[1:] | strip([]) | unwrap
      else . end
  end;
def found:
  (to_entries | map(select(.value | IN("-exec", "-execdir", "-ok", "-okdir"))) | first | .key) as $i
  | if $i == null then empty else .[$i + 1:] | (index(";") // index("+") // length) as $j | .[:$j] | unwrap end;

def shells: ["sh", "bash", "zsh", "dash", "ksh"];
def hostfile: test("\\.claude/(ssh-hosts|outbound-hosts|settings(\\.local)?\\.json)");
def readonly($c; $p):
  (["cat", "head", "tail", "less", "grep", "rg", "wc", "jq", "ls", "stat", "diff", "echo", "printf"] | has_($c))
  or ($c == "git" and (["diff", "log", "show", "blame", "status", "add", "commit"] | has_($p[0] // "")));
def method:
  [foreach .[] as $t ({prev: null, m: null};
    {prev: $t, m: (if .prev == "-X" or .prev == "--method" then $t
      elif ($t | test("^-X.")) then $t[2:]
      elif ($t | startswith("--method=")) then $t[9:]
      else .m end)};
    .m)] | last // null | if . == null then null else ascii_upcase end;

def rules($hdocs):
  .argv as $a | ($a[0] // "" | name) as $c | [$a[1:][] | select(startswith("-") | not)] as $p
  | (if $c == "kubectl" and ($p | has_("delete")) then
      (if $p | after("delete") | any(test("^(ns|namespaces?)(/|$)")) then "block\tkubectl delete namespace." else empty end),
      (if $a | any(test("^--all(=true)?$")) then "block\tkubectl delete --all." else empty end)
    else empty end),
    (([$a | to_entries[] | select(.value | name | test("^skills(@|$)")) | .key] | first) as $s
      | if $s != null
          and (["add", "install", "i", "a", "remove", "rm", "update", "upgrade"] | has_($a[$s + 1] // ""))
          and ($a[$s + 2:] | any(. == "--global" or test("^-[a-zA-Z]*g[a-zA-Z]*$")))
        then "block\tglobal skill install. skills live in nix-config (home/cli/claude/default.nix), declare it there."
        else empty end),
    (if (["gh", "glab"] | has_($c)) and $p[0] == "api" then
      ($a[1:] | method) as $m
      | if ["POST", "PUT", "PATCH", "DELETE"] | has_($m) then "block\tgh api with a write method. reading the api is fine, writing is not."
        elif $m != "GET" and ($a | any(test("^(-f|-F|--field|--raw-field|--input)(=|$)") or test("^-[fF]."))) then
          "block\tgh api with fields defaults to POST. add --method GET if you meant to read."
        else empty end
    else empty end),
    (if $c == "nix" and ($p | has_("copy")) and ($a | any(test("^--to(=|$)"))) then
      "block\tnix copy to a remote store. what leaves this machine is the user's call."
    else empty end),
    (if $c == "osascript" and (($a[1:] + $hdocs) | join(" ") | test("(Mail|Messages)[\\s\\S]*\\ssend(\\s|$)")) then
      "block\tsending mail or a message via applescript. that is the user's to send."
    else empty end),
    (if ($a[1:] | any(hostfile)) and (readonly($c; $p) | not) then
      "block\twriting .claude/ssh-hosts, outbound-hosts or project settings. the user maintains those."
    else empty end),
    (if (shells | has_($c)) then
      ($a[1:] | to_entries | map(select(.value | test("^-[a-zA-Z]*c[a-zA-Z]*$"))) | first | .key) as $i
      | if $i != null then "shell\t\($a[$i + 2] // "" | @json)"
        elif ($a[1:] | map(select(startswith("-") | not)) | length) == 0 then ($hdocs[] | "shell\t\(@json)")
        else empty end
    elif $c == "eval" then "shell\t\($a[1:] | join(" ") | @json)"
    else empty end),
    (if ((["darwin-rebuild", "nixos-rebuild", "home-manager"] | has_($c)) and ($p | any(IN("switch", "activate", "boot", "test"))))
      or ($c == "nh" and (["os", "darwin", "home"] | has_($p[0] // "")) and (["switch", "boot", "test"] | has_($p[1] // "")))
      or ($c == "mise" and ($p | any(IN("deploy", "rollback"))))
      or (($a[0] // "") | test("(^|/)scripts/(deploy|rollback)\\.sh$"))
      or ((shells | has_($c)) and (($a[1] // "") | test("(^|/)scripts/(deploy|rollback)\\.sh$")))
      or ((["terraform", "tofu", "terragrunt"] | has_($c)) and ($p | any(IN("apply", "destroy"))))
      or ($c == "kubectl" and ($p | has_("apply")))
    then "ask\ta deploy. deploys run only when the user asked for this one."
    else empty end);

(if any(.. | objects | select(.Type? == "FuncDecl"); .Name.Value == ":") then "block\tfork bomb." else empty end),
(.. | objects | select(.Cmd?.Type == "CallExpr")
  | [.Redirs[]? | .Hdoc | select(. != null) | word] as $hdocs
  | (.Redirs[]? | select(.Op | IN(">", ">>", ">|", "&>", "&>>", "<>", ">&")) | .Word | word | select(hostfile)
      | "block\twriting .claude/ssh-hosts, outbound-hosts or project settings. the user maintains those."),
    ({argv: ([.Cmd.Args[]? | word] | unwrap)} | rules($hdocs), (.argv | found | {argv: .} | rules([]))))
