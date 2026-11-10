# package overrides. empty most of the time, that is fine. args are underscored
# because deadnix flags unused ones, drop the underscore on what you use.
inputs: _final: prev: {
  # new models need the newest claude-code, unstable trails master by days
  inherit
    (import inputs.nixpkgs-master {
      inherit (prev.stdenv.hostPlatform) system;
      config.allowUnfree = true;
    })
    claude-code
    ;
}
