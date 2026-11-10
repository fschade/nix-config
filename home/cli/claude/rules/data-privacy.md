# Data and privacy

- Gitignored is a vault. Reading it for the work is fine; its contents and file
  names never go into anything tracked or outward (code, docs, tests, commits,
  PR text). Refer to it abstractly: "a token", "the local dump".
- No real people in examples, tests or docs, me included: alice, bob,
  jane@example.com.
- Made-up infrastructure uses reserved values: example.com/.org,
  192.0.2.x / 198.51.100.x / 203.0.113.x, 2001:db8::/32. Never real hosts, IPs
  or tokens of mine.
- Secrets never in code, logs, comments, commits or replies; redact them when
  quoting output.
- Secrets never literally in a command: `$GITHUB_TOKEN`, `$(gh auth token)`. A
  leaked secret gets rotated, deleting history is not enough.
- User-facing errors never carry sensitive data; details go to the server log.
