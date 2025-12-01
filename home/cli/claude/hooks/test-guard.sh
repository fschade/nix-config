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

if [ "$tool" = "Edit" ]; then
  new="$(jq -r '.tool_input.new_string // empty' <<<"$json")"
  old="$(jq -r '.tool_input.old_string // empty' <<<"$json")"
else
  new="$(jq -r '.tool_input.content // empty' <<<"$json")"
  old=""
  [ -f "$file" ] && old="$(cat "$file")"
fi

pat='t\.Skip|\.skip\(|\.only\(|xit\(|xdescribe\(|xtest\(|@pytest\.mark\.skip|pytest\.skip\(|#\[ignore\]'
newc=$(grep -cE "$pat" <<<"$new" || true)
oldc=$(grep -cE "$pat" <<<"$old" || true)

if [ "$newc" -gt "$oldc" ]; then
  echo "BLOCKED by test-guard: this change adds skip/only markers to a test (t.Skip / .skip / .only / xit / ...). fix the test instead of muting it — if skipping is really wanted, the user does it." >&2
  exit 2
fi
exit 0
