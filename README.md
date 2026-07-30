# Nix Config

Declarative config for my macOS and Linux machines.

<p align="center">
  <img src="assets/yoshi.gif" width="300" alt="Yoshi the dog, captioned 'my home'" />
  <br><em>home-manager takes care of <code>$HOME</code>. Yoshi takes care of home.</em>
</p>

## Setup

**macOS** (whole machine, nix-darwin):

```bash
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
sudo nix run nix-darwin -- switch --flake .#$HOST
```

**Linux** (home-manager):

```bash
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
nix run home-manager/master -- switch -b backup --flake .#$USER@$HOST
```

## Commands

```bash
mise run deploy [target]   # build + switch (default: this machine)
mise run rollback          # macOS: previous generation. linux: lists them, you pick
mise run gc [30d]          # drop generations older than that, then collect the store
mise run check             # fmt + lint + secret gates + the claude hook tests
mise run fmt               # format nix files
mise run apps              # list the apps/CLIs you declared (nix packages + casks)
mise run flake-update      # bump inputs (skips the churny homebrew taps)
mise run brew-update       # bump homebrew taps, then deploy to pull them
```

CI runs `check` too, plus a commit-message lint and a per-system build of every
host config. Commit subjects are lowercase by convention only: `committed` has
no setting for it, `subject_capitalized = false` just turns its capitalization
check off.

`deploy` routes by target: `user@host` goes to home-manager, a bare name to
nix-darwin.
Deploy any config explicitly, e.g. `mise run deploy fschade@darwin-default`.

## Dev

```bash
direnv allow   # or: nix develop
```

Loads the toolchain (mise + gate tools) and installs git hooks. CI runs the same shell.

## Thanks

Standing on the shoulders of giants!

- [Nix](https://github.com/NixOS/nix)
- [nix-darwin](https://github.com/nix-darwin/nix-darwin)
- [home-manager](https://github.com/nix-community/home-manager)
- [Determinate Nix](https://docs.determinate.systems/)
- [ryan4yin/nix-config](https://github.com/ryan4yin/nix-config)

Huge thanks to everyone who builds and shares this stuff. 🐶
