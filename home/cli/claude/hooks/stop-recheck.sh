#!/usr/bin/env bash
# Stop hook: one forced look at the request before a longer answer stands as final.
# skips turns without tool calls, short replies, open questions, waiting on background work and its own continuation.
set -euo pipefail

# a continuation replaces the final result of `claude -p`, and scripts read that
[ "${CLAUDE_CODE_ENTRYPOINT:-}" = cli ] || exit 0

json="$(cat)"
tp="$(jq -r '.transcript_path // empty' <<<"$json")"
# a turn starts at the last user entry that is not only tool results. no transcript, no skip
tools=true
if [ -n "$tp" ] && [ -r "$tp" ]; then
  tools="$(jq -n 'reduce (inputs | select(.type == "user" or .type == "assistant")) as $e (false;
    if $e.type == "user" then
      (if ($e.message.content | type) == "array" and ($e.message.content | all(.type == "tool_result")) then . else false end)
    else . or any($e.message.content[]?; .type == "tool_use") end)' "$tp")"
fi

jq -c --argjson tools "$tools" '
  select(
    $tools
    and (.stop_hook_active | not)
    and ((.background_tasks // []) | length == 0)
    and ((.last_assistant_message // "" | sub("\\s+$"; "")) as $msg
      | ($msg | length) >= 200 and ($msg | endswith("?") | not))
  )
  | {hookSpecificOutput: {
      hookEventName: "Stop",
      additionalContext: "Before finishing: go through the last user request item by item and compare it with what you just reported. Do what is still open and in scope, and name what you left out. If nothing is open, reply only: nothing open."
    }}
' <<<"$json"
