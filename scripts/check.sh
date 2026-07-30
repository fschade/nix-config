#!/usr/bin/env bash

set -euo pipefail

# the tools below take relative paths, so run from the repo root even when
# invoked directly from elsewhere
cd "$(dirname "$0")/.."

# statix reads .gitignore, alejandra and deadnix dont. so hand the two the same
# set git would show, otherwise a stray nix file in tmp/ blocks every commit
mapfile -d '' -t nix_files < <(git ls-files -z --cached --others --exclude-standard '*.nix')
# `deadnix --fail` with no arguments exits 0, so an empty list would pass the
# gate without checking anything
if [ "${#nix_files[@]}" -eq 0 ]; then
  echo "no nix files found, refusing to run the gates on nothing." >&2
  exit 1
fi
alejandra --check "${nix_files[@]}"
deadnix --fail "${nix_files[@]}"
statix check .

# shell scripts by shebang, from the same git-tracked set. no shfmt: that is a
# formatter and would impose a style, shellcheck catches the bugs. vendored files
# carry a "vendored" marker in their header and are upstream's to lint, not ours.
sh_files=()
while IFS= read -r f; do
  [ -f "$f" ] || continue
  head -1 "$f" | grep -qE '^#!.*(bash|/sh| sh)' || continue
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

# dir scan covers the working tree, git scan the history. a secret that was
# committed and later removed would pass the dir scan forever
gitleaks dir . --no-banner
gitleaks git . --no-banner

# the claude guard hooks are code with a test suite, so they belong in the gate:
# a pattern that stops matching is exactly what nobody notices.
./home/cli/claude/hooks/run-tests.sh
