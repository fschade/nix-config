# overrides or fixes
#
#   inputs: final: prev: {
#     somepkg = prev.somepkg.overrideAttrs (_: { ... });
#   }
_inputs: _final: prev: {
  # croc 10.4.5's src hash in nixpkgs is stale (GitHub archive-tarball drift) →
  # the build fails with a hash mismatch on source.drv, and it isn't cached. Pin
  # the correct hash. Remove once nixpkgs ships a croc that builds/caches again.
  croc = prev.croc.overrideAttrs (old: {
    src = old.src.overrideAttrs (_: {
      outputHash = "sha256-u262LwHUL6+rPE7nzIda7W5dAXaikQ/cKwtUEIbcbH0=";
    });
  });
}
