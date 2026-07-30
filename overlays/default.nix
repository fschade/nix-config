# package overrides. empty most of the time, that is fine. args are underscored
# because deadnix flags unused ones, drop the underscore on what you use.
#
#   _inputs: _final: prev: {
#     somepkg = prev.somepkg.overrideAttrs (_: {...});
#   }
_inputs: _final: _prev: {
}
