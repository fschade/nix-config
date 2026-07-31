#!/usr/bin/env bash
# claude code PreToolUse guard for Edit/Write on test files. blocks edits that
# ADD skip/only markers (silently muting a failing test is a classic agent
# failure mode). diff aware: only fires when the new content has more markers
# than the old one, so files that already contain skips stay editable.
# idea from AnastasiyaW/claude-code-config test-muting-guard, rewritten.
set -euo pipefail

# block on a payload we cannot parse, like bash-guard: any exit but 2 is
# non-blocking, so failing open would let a malformed edit skip the guard.
json="$(cat)"
tool="$(jq -r '.tool_name // empty' <<<"$json")" || {
  echo "BLOCKED by test-guard: unreadable hook input. it does not let through what it cannot parse." >&2
  exit 2
}
# NotebookEdit names its file notebook_path, everything else file_path
file="$(jq -r '.tool_input.file_path // .tool_input.notebook_path // empty' <<<"$json")"
[ -z "$file" ] && exit 0

case "$file" in
*_test.go | *.test.* | *.spec.* | */test_*.py | test_*.py | *_test.py) ;;
*) exit 0 ;;
esac

# an Edit only carries its fragment, so the counting below sees new_string, not
# the file around it: a t.Skip whose guarding if sits outside the replaced text
# reads as unguarded and blocks.
# the settings matcher Edit|Write also routes MultiEdit and NotebookEdit here.
# neither speaks the Write branch's dialect: a MultiEdit there read an absent
# content field and could never block, NotebookEdit carries new_source. so each
# gets its own branch, and an editing tool we do not know fails closed rather
# than passing a possibly-muting edit through.
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
  # the payload holds only the new cell source, no old content to diff. so no
  # added-vs-present distinction here: any marker in the new source blocks,
  # a notebook that keeps a pre-existing skip is the user's edit to make.
  new="$(jq -r '.tool_input.new_source // empty' <<<"$json")"
  old=""
  ;;
Write)
  new="$(jq -r '.tool_input.content // empty' <<<"$json")"
  old=""
  if [ -f "$file" ]; then
    # a cat failure after the -f check (permissions, a race) exits 1 under
    # set -e, which is non-blocking: the write would pass unchecked. fail
    # closed instead.
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

# go, javascript/typescript and python only, per the file filter above. rust is
# out: its test are `#[ignore]` in any .rs file, and letting .rs through would
# make every `iter.skip(n)` look like a muted test.
#
# t.Skip / pytest.skip with an if on the same or one of the 3 previous lines is
# a dependency probe ("skip when the dependency is absent"), not muting, so it
# does not count. @pytest.mark.skipif is conditional anyway and never counts.
# t.Skip needs a non-word char in front, otherwise client.Skip(...) counts too.
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
