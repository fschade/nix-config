#!/usr/bin/env bash

set -euo pipefail

cd "$(dirname "$0")/.."

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

# with a `# shellcheck shell=` directive (direnv stdlib bits have no shebang).
# style, shellcheck catches the bugs. vendored files carry a "vendored" marker in
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
shellcheck --severity=warning "${sh_files[@]}"

if command -v swiftc >/dev/null 2>&1; then
  while IFS= read -r f; do
    [ -f "$f" ] || continue
    swiftc -parse "$f" >/dev/null
  done < <(git ls-files --cached --others --exclude-standard 'tools/web-app/*.swift')
fi

# git modes, not `dir`: dir walks ignored files too and errors on unreadable ones
gitleaks git . --pre-commit --no-banner --log-level warn
gitleaks git . --pre-commit --staged --no-banner --log-level warn
gitleaks git . --no-banner --log-level warn
