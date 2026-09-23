#!/usr/bin/env bash
set -euo pipefail

json="$(cat)"
tool="$(jq -r '.tool_name // empty' <<<"$json")" || {
  echo "BLOCKED by test-guard: unreadable hook input. it does not let through what it cannot parse." >&2
  exit 2
}
file="$(jq -r '.tool_input.file_path // .tool_input.notebook_path // empty' <<<"$json")"
[ -z "$file" ] && exit 0

case "$file" in
*_test.go | *.test.* | *.spec.* | */test_*.py | test_*.py | *_test.py) ;;
*) exit 0 ;;
esac

case "$tool" in
Edit)
  new="$(jq -r '.tool_input.new_string // empty' <<<"$json")"
  old="$(jq -r '.tool_input.old_string // empty' <<<"$json")"
  ;;
MultiEdit)
  new="$(jq -r '[.tool_input.edits[]?.new_string] | join("\n")' <<<"$json")"
  old="$(jq -r '[.tool_input.edits[]?.old_string] | join("\n")' <<<"$json")"
  ;;
NotebookEdit)
  new="$(jq -r '.tool_input.new_source // empty' <<<"$json")"
  old=""
  ;;
Write)
  new="$(jq -r '.tool_input.content // empty' <<<"$json")"
  old=""
  if [ -f "$file" ]; then
    old="$(cat "$file")" || {
      echo "BLOCKED by test-guard: cannot read $file to diff against, refusing to pass the write unchecked." >&2
      exit 2
    }
  fi
  ;;
*)
  echo "BLOCKED by test-guard: unhandled tool '$tool' on a test file, cannot check for a skip." >&2
  exit 2
  ;;
esac

count_markers() {
  awk '
    { hist[NR] = $0 }
    /(^|[^[:alnum:]_])t\.Skip|pytest\.skip\(/ {
      guarded = 0
      for (i = NR - 3; i <= NR; i++)
        if (hist[i] ~ /(^|[[:space:];{}])if[[:space:](]/) guarded = 1
      if (!guarded) n++
      next
    }
    /\.only\(|\.skip\(|(^|[^[:alnum:]_])x(it|describe|test)\(|@pytest\.mark\.skip($|[^i])/ { n++ }
    END { print n + 0 }
  '
}

newc=$(count_markers <<<"$new")
oldc=$(count_markers <<<"$old")

if [ "$newc" -gt "$oldc" ]; then
  echo "BLOCKED by test-guard: this change adds an unconditional skip/only marker to a test (t.Skip / .skip / .only / xit / ...). fix the test instead of muting it. skipping is only ok as a dependency probe (if <dependency missing> { t.Skip(...) }). anything else the user decides." >&2
  exit 2
fi
exit 0
