# Data and privacy

- Gitignored is a vault. What .gitignore excludes (env files, dumps, local
  state, caches, tmp/) exists only on this machine and stays there: never
  quote, copy or reference its contents or its file names in anything tracked
  or outward-facing, no code, no docs, no tests, no fixtures, no commit
  message, no PR text. Reading one for the work at hand is fine; what it held
  leaves the vault only as an abstraction ("a token", "the local dump"), never
  as the value or the path. The coupling side of this, tracked code pointing
  at a gitignored path, is in `hygiene.md`.
- Never put real people into examples, tests, fixtures, or docs: no real names,
  emails, usernames, or accounts, mine included. Use obvious placeholders
  ("alice", "bob", jane@example.com).
- Made-up infrastructure uses reserved values: example.com/.org (RFC 2606),
  192.0.2.x / 198.51.100.x / 203.0.113.x (RFC 5737), 2001:db8::/32 (RFC 3849).
  Never real hostnames, IPs, or tokens from my machines or homelab.
- Secrets never end up in code, logs, comments, commit messages, or replies.
  When a command output contains one, redact it when you quote it.
- Secrets never go literally into command strings. Use references like
  `$GITHUB_TOKEN` or `$(gh auth token)` so the value stays out of transcripts.
  If a raw secret does leak, it gets rotated. Deleting history is not enough.
- Error messages never expose sensitive data. Detailed context goes into the
  server-side log, not the user-facing error.
