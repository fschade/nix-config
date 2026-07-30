#!/usr/bin/env bash
# claude code PreToolUse guard for Edit/Write on test files. blocks edits that
# ADD skip/only markers (silently muting a failing test is a classic agent
# failure mode). diff aware: only fires when the new content has more markers
# than the old one, so files that already contain skips stay editable.
# idea from AnastasiyaW/claude-code-config test-muting-guard, rewritten.
set -euo pipefail

json="$(cat)"
tool="$(jq -r '.tool_name // empty' <<<"$json")"
file="$(jq -r '.tool_input.file_path // empty' <<<"$json")"
[ -z "$file" ] && exit 0

case "$file" in
*_test.go | *.test.* | *.spec.* | */test_*.py | test_*.py) ;;
*) exit 0 ;;
esac

# an Edit only carries its fragment, so the counting below sees new_string, not
# the file around it: a t.Skip whose guarding if sits outside the replaced text
# reads as unguarded and blocks.
if [ "$tool" = "Edit" ]; then
  new="$(jq -r '.tool_input.new_string // empty' <<<"$json")"
  old="$(jq -r '.tool_input.old_string // empty' <<<"$json")"
else
  new="$(jq -r '.tool_input.content // empty' <<<"$json")"
  old=""
  [ -f "$file" ] && old="$(cat "$file")"
fi

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
