utils := absolute_path("./lib/utils.sh")
divider := "#################################################################"

############################################################################
#
#  Common commands(suitable for all machines)
#
############################################################################

default:
    @just --list

# Update all the flake inputs
[group('nix')]
up:
  nix flake update --commit-lock-file

# Update specific input
# Usage: just upp nixpkgs
[group('nix')]
upp input:
  nix flake update {{input}} --commit-lock-file

# List all generations of the system profile
[group('nix')]
history:
  nix profile history --profile /nix/var/nix/profiles/system

# Open a nix shell with the flake
[group('nix')]
repl:
  nix repl -f flake:nixpkgs

# Garbage collect all unused nix store entries
[group('nix')]
gc:
  # garbage collect all unused nix store entries(system-wide)
  sudo nix-collect-garbage --delete-older-than 7d
  # garbage collect all unused nix store entries(for the user - home-manager)
  # https://github.com/NixOS/nix/issues/8508
  nix-collect-garbage --delete-older-than 7d

# Enter a shell session which has all the necessary tools for this flake
[group('nix')]
shell:
  nix shell nixpkgs#git nixpkgs#neovim

[group('nix')]
fmt:
  # format the nix files in this repo
  alejandra --quiet .

# Show all the auto gc roots in the nix store
[group('nix')]
gcroot:
  ls -al /nix/var/nix/gcroots/auto/

# Verify all the store entries
# Nix Store can contains corrupted entries if the nix store object has been modified unexpectedly.
# This command will verify all the store entries,
# and we need to fix the corrupted entries manually via `sudo nix store delete <store-path-1> <store-path-2> ...`
[group('nix')]
verify-store:
  nix store verify --all


# Repair Nix Store Objects
[group('nix')]
repair-store *paths:
  nix store repair {{paths}}

# Update all Nixpkgs inputs
[group('nix')]
up-nix:
  nix flake update nixpkgs

############################################################################
#
#  Darwin related commands
#
############################################################################

[group('desktop')]
[macos]
local target mode="default":
  #!/usr/bin/env bash
  . "{{ utils }}"
  build-darwin "{{ target }}" "{{ mode }}"
  switch-darwin "{{ target }}" "{{ mode }}"

[group('desktop')]
[macos]
rollback:
  #!/usr/bin/env bash
  . "{{ utils }}"
  rollback-darwin