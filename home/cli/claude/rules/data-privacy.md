# Data and privacy

- Never put real people into examples, tests, fixtures, or docs: no real names,
  emails, usernames, or accounts — mine included. Use obvious placeholders
  ("alice", "bob", jane@example.com).
- Made-up infrastructure uses reserved values: example.com/.org (RFC 2606),
  192.0.2.x / 198.51.100.x / 203.0.113.x (RFC 5737), 2001:db8::/32 (RFC 3849).
  Never real hostnames, IPs, or tokens from my machines or homelab.
- Secrets never end up in code, logs, comments, commit messages, or replies.
  When a command output contains one, redact it when you quote it.
- Secrets never go literally into command strings — use references like
  `$GITHUB_TOKEN` or `$(gh auth token)` so the value stays out of transcripts.
  If a raw secret does leak, it gets rotated — deleting history is not enough
  (via ryoppippi/dotfiles, thanks).
- Error messages never expose sensitive data — detailed context goes into the
  server-side log, not the user-facing error
  (via affaan-m/everything-claude-code, thanks).
