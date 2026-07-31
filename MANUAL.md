# manual steps

stuff nix cant do for you. do after a fresh `mise run deploy`.

## gatekeeper quarantine (one-time cleanup)
nix-darwin only writes defaults keys, it never deletes them, so an unmanaged
`LSQuarantine` key just sits there. once, to get the macOS default back:

    defaults delete com.apple.LaunchServices LSQuarantine

## stray pnpm rc (one-time cleanup)
home-manager owns `~/.config/pnpm/config.yaml` now, an unmanaged `rc` file sits
next to it and says `strict-ssl=undefined`. pnpm 11 never reads it, it only
misleads the next time you look in there:

    rm ~/.config/pnpm/rc

## keyboard shortcuts (one-time cleanup)
`com.apple.symbolichotkeys` holds nothing but key 64 (spotlight) here, every
other shortcut sits at factory. the switch merges with `-dict-add` now and
leaves the rest alone, but it brings nothing back. set the ones you want once in
system settings > keyboard > keyboard shortcuts. aerospace wants the mission
control ones off: ctrl-1..ctrl-9 space switching (keys 118-127) and the
move-a-space arrows (79-82). what is set right now:

    defaults read com.apple.symbolichotkeys AppleSymbolicHotKeys

## macshot hotkey vs brave (⇧⌘T)
macshot registers ⇧⌘T globally, so it wins over brave's "reopen closed tab" and
that shortcut just does nothing in the browser. its hotkeys live in the app, not
in defaults, so nix cant set them: open macshot > settings > shortcuts and put it
on something else.

## serena mcp (per-project opt-in)
serena is opt-in per repo, never global. `serena` is on PATH (uvx wrapper), so
inside a project you want it in:

    claude mcp add serena -- serena start-mcp-server --context claude-code --project-from-cwd

## obsbot center
no cask, only signed download urls. install by hand from obsbot.com.
login item is already set, so it autostarts once installed.

## mac app store apps (one-time, per apple account)
`mas` can only install what your apple account already owns. every entry in
modules/darwin/apps.nix `masApps` (and the host's own, e.g. MoneyMoney) has to be
"bought" once by hand in the App Store, else the switch cant pull it.

## login items
the reconcile runs osascript against System Events. a denied prompt makes the
switch warn ("cannot reach System Events") and leaves the login items alone, so
grant it once:
system settings > privacy & security > automation > allow your terminal (and
`darwin-rebuild`) to control **System Events**.

## web apps (dashboard, pushover, opentalk on this mac)
native WKWebView wrappers, built into /Applications during `mise run deploy` (nix
cant build them: needs swiftc from xcode). how they work, the manifest format and
the `mise run web-app` builder are documented in **tools/web-app/README.md**. what
needs a human here:

- one-time grants (system settings > privacy & security), asked on first use:
  notifications (else desktop notifications stay silent), and camera + mic for
  opentalk (plus screen recording if you share a screen).
- sharing a DMG (`mise run web-app dmg <path>`): the first run wants "control Finder"
  (Automation) to style the installer window. grant it, or it ships a plain (still
  working) DMG. the shared app is ad-hoc signed, so the recipient does the gatekeeper
  "open anyway" dance once (spelled out in the bundled "Read me first" note).

## karabiner (umlauts + tilde)
first run needs approval, else ä ö ü ~ stay dead:
- system settings > privacy & security > allow the karabiner system extension
- system settings > privacy & security > input monitoring > enable karabiner
check it runs: `pgrep karabiner_grabber`.

## aerospace (tiling wm)
first run needs accessibility, else it cant move windows:
- system settings > privacy & security > accessibility > enable AeroSpace

check it runs: `aerospace list-workspaces --focused` (it errors with "Can't
connect to AeroSpace server" when the daemon is down). a config change from a
switch only takes after `aerospace reload-config`.

## keyboard layout (keebwerk mega, optional)
export your VIA layout to custom/config/keyboard/keebwerk-mega.json to
version it. see the readme there.
