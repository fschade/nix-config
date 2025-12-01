#!/usr/bin/env bash

divider="#################################################################"

build () {
  local target=".#$1"
  local mode=$2

  echo "$divider"
  echo "# build '($target)' in '($mode)' mode..."
  echo "$divider"

  if [ $mode = "debug" ]; then
    nom build "$target" --show-trace --verbose
  else
    nix build "$target" "nix-command flakes"
  fi
}

build-darwin () {
    local target=".#darwinConfigurations.$1.system"
    local mode=$2

    echo "$divider"
    echo "# build '($target)' in '($mode)' mode..."
    echo "$divider"

    if [ $mode = "debug" ]; then
      nom build "$target" --extra-experimental-features "nix-command flakes"  --show-trace --verbose
    else
      nix build "$target" --extra-experimental-features "nix-command flakes"
    fi
}

switch () {
  local target=".#$1"
  local mode=$2

  echo "$divider"
  echo "# switch '($target)' in '($mode)' mode..."
  echo "$divider"

  if [ $mode = "debug" ]; then
    nixos-rebuild switch --sudo --flake "$target" --show-trace --verbose
  else
    nixos-rebuild switch --sudo --flake "$target"
  fi
}

switch-darwin () {
  local target=".#$1"
  local mode=$2

  echo "$divider"
  echo "# switch '($target)' in '($mode)' mode..."
  echo "$divider"

  if [ $mode = "debug" ]; then
    sudo ./result/sw/bin/darwin-rebuild switch --flake "$target" --show-trace --verbose
  else
    sudo ./result/sw/bin/darwin-rebuild switch --flake "$target"
  fi
}

rollback-darwin () {
  echo "$divider"
  echo "# rollback..."
  echo "$divider"

  sudo ./result/sw/bin/darwin-rebuild --rollback
}