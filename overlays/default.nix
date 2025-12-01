# overrides or fixes
#
#   inputs: final: prev: {
#     somepkg = prev.somepkg.overrideAttrs (_: { ... });
#   }
_inputs: _final: prev: {
  # croc 10.4.5 src hash in nixpkgs is stale (github tarball drift), build fails with hash mismatch and no cache.
  # pin the right hash. remove once nixpkgs ships a croc that builds again.
  croc = prev.croc.overrideAttrs (old: {
    src = old.src.overrideAttrs (_: {
      outputHash = "sha256-u262LwHUL6+rPE7nzIda7W5dAXaikQ/cKwtUEIbcbH0=";
    });
  });
}
