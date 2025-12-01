# My System Configuration

This repository contains my **Nix conf for configuring and managing all of my machines**.
It defines system settings, installed packages, development environments,
and various tools—allowing every machine to be reproducible, declarative, and easy to redeploy.

The goal is to have a single source of truth for my entire setup, so any system can be rebuilt consistently from
scratch.

---

## How to Deploy

```bash
# If you are deploying for the first time,
# 1. install nix (https://docs.determinate.systems/)
# 2. install homebrew if needed (https://brew.sh/)
# 3. prepare the deployment environment with essential packages available
nix-shell -p just

# Deploy the configuration matched by hostname
just local

# Deploy with detailed logs
just local debug
```

As the repository grows, additional deployment targets for different platforms or host types will be added.

---

## Acknowledgements

### Configuration Inspiration

This setup draws inspiration from various excellent Nix configuration repositories shared by the community.
Special thanks to:

* [ryan4yin/nix-config](https://github.com/ryan4yin/nix-config/tree/main)

Thank you for sharing your work and ideas!

### Tooling

Many thanks to the developers and maintainers of the tools that make reproducible systems possible:

* [Nix](https://github.com/NixOS/nix)
* [nix-darwin](https://github.com/LnL7/nix-darwin)
* [home-manager](https://github.com/nix-community/home-manager)
* [Determinate Systems Nix installer](https://github.com/DeterminateSystems/nix-installer)
