#!/usr/bin/env bash

set -euo pipefail

# the tools below take relative paths, so run from the repo root even when
# invoked directly from elsewhere
cd "$(dirname "$0")/.."

# statix reads .gitignore, alejandra and deadnix dont. hand the two the same set
# git would show, minus files deleted from the worktree: `git ls-files` still
# lists a deletion that is not staged. neither tool flags the missing path:
# alejandra "checks" it as zero files green, deadnix stat-errors but exits 0.
# same `[ -f ]` filter the shell loop below uses.
nix_files=()
while IFS= read -r -d '' f; do
  [ -f "$f" ] && nix_files+=("$f")
done < <(git ls-files -z --cached --others --exclude-standard '*.nix')
if [ "${#nix_files[@]}" -eq 0 ]; then
  echo "no nix files found, refusing to run the gates on nothing." >&2
  exit 1
fi
alejandra --check "${nix_files[@]}"
deadnix --fail "${nix_files[@]}"
statix check .

# shell scripts by shebang, plus sourced fragments that declare their dialect
# with a `# shellcheck shell=` directive (direnv stdlib bits have no shebang).
# from the same git-tracked set. no shfmt: that is a formatter and would impose a
# style, shellcheck catches the bugs. vendored files carry a "vendored" marker in
# their header and are upstream's to lint, not ours.
sh_files=()
while IFS= read -r f; do
  [ -f "$f" ] || continue
  head -1 "$f" | grep -qE '^#!.*(bash|/sh| sh)' ||
    head -5 "$f" | grep -qE '^#[[:space:]]*shellcheck[[:space:]]+shell=' ||
    continue
  head -5 "$f" | grep -qi 'vendored' && continue
  sh_files+=("$f")
done < <(git ls-files --cached --others --exclude-standard)
if [ "${#sh_files[@]}" -eq 0 ]; then
  echo "no shell scripts found, refusing to run the gate on nothing." >&2
  exit 1
fi
# warning and up: real bugs (unquoted splits, undefined vars), not the info-level
# style nags. the hook test file is full of single-quoted fixture commands that
# read as SC2016 but are meant literally.
shellcheck --severity=warning "${sh_files[@]}"

# the web-app builder is a swift script nix just runs, and the host sources it
# compiles have no build gate either, so a syntax slip would only surface at
# deploy. parse-check every tracked swift file there (Package.swift included)
# when a toolchain is around (CI runs on linux and has none, so guard on the
# binary). one file at a time: together they parse as one module and the
# builder's hashbang and top-level code are only legal alone.
if command -v swiftc >/dev/null 2>&1; then
  while IFS= read -r f; do
    [ -f "$f" ] || continue
    swiftc -parse "$f" >/dev/null
  done < <(git ls-files --cached --others --exclude-standard 'tools/web-app/*.swift')
fi

# dir scan covers the working tree, git scan the history. a secret that was
# committed and later removed would pass the dir scan forever
gitleaks dir . --no-banner
gitleaks git . --no-banner

# the claude guard hooks are code with a test suite, so they belong in the gate:
# a pattern that stops matching is exactly what nobody notices. slow enough that
# the pre-commit hook runs it glob-scoped instead and sets the skip, see
# lefthook.yml.
if [ "${CHECK_SKIP_HOOK_TESTS:-}" != "1" ]; then
  ./home/cli/claude/hooks/run-tests.sh
fi
