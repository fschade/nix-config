# manual steps

stuff nix cant do for you. do after a fresh `mise run deploy`.

## obsbot center
no cask, only signed download urls. install by hand from obsbot.com.
login item is already set, so it autostarts once installed.

## web apps (opentalk, opencloud, pushover, …)
native WKWebView wrappers, built into /Applications during `mise run deploy` (nix
cant build them — needs swiftc from xcode). how they work, the manifest format and
the `mise run web-app` builder are documented in **tools/web-app/README.md**. what
needs a human here:

- one-time grants (system settings > privacy & security), asked on first use:
  notifications (else desktop notifications stay silent), and camera + mic for
  opentalk (plus screen recording if you share a screen).
- sharing a DMG (`mise run web-app dmg <path>`): the first run wants "control Finder"
  (Automation) to style the installer window — grant it, or it ships a plain (still
  working) DMG. the shared app is ad-hoc signed, so the recipient does the gatekeeper
  "open anyway" dance once (spelled out in the bundled "Read me first" note).

## karabiner (umlauts + tilde)
first run needs approval, else ä ö ü ~ stay dead:
- system settings > privacy & security > allow the karabiner system extension
- system settings > privacy & security > input monitoring > enable karabiner
check it runs: `pgrep karabiner_grabber`.

## keyboard layout (keebwerk mega, optional)
export your VIA layout to custom/config/keyboard/keebwerk-mega.json to
version it. see the readme there.
