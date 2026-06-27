#!/usr/bin/env bash

set -euo pipefail

alejandra --check --exclude ./.direnv .
deadnix --fail .
statix check --ignore .direnv .
gitleaks dir . --no-banner
