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
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
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
mise run rollback          # previous generation
mise run check             # fmt + lint + secret gates (what CI runs)
mise run fmt               # format nix files
```

`deploy` routes by target: `user@host` → home-manager, bare name → nix-darwin.
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
