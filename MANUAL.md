# manual steps

stuff nix cant do for you. do after a fresh `mise run deploy`.

## after a macOS major update
nix comes back on its own. permission grants do not: check karabiner, aerospace
and background items below. check one-liners are in the navi cheats under
`nix, macos`.

## gatekeeper quarantine (one-time cleanup)
an unmanaged `LSQuarantine` key nix-darwin will never delete:

    defaults delete com.apple.LaunchServices LSQuarantine

## stray pnpm rc (one-time cleanup)
an unmanaged `rc` next to the managed `config.yaml`, pnpm 11 never reads it:

    rm ~/.config/pnpm/rc

## keyboard shortcuts (one-time cleanup)
`com.apple.symbolichotkeys` holds only key 64 (spotlight), the rest is factory.
the switch merges with `-dict-add` and brings nothing back. aerospace wants the
mission control ones off: ctrl-1..9 space switching (118-127) and the
move-a-space arrows (79-82). current state:

    defaults read com.apple.symbolichotkeys AppleSymbolicHotKeys

## macshot hotkey vs brave (⇧⌘T)
macshot takes ⇧⌘T globally and its hotkeys live in the app, not defaults. move it
in macshot > settings > shortcuts.

## serena mcp (per-project opt-in)
`serena` is on PATH, opt in per repo:

    claude mcp add serena -- serena start-mcp-server --context claude-code --project-from-cwd

## obsbot center
no cask, signed download urls only. install by hand from obsbot.com. the login
item is set, so it autostarts once installed.

## libation (audible account, one-time)
add the audible account in the app (accounts > add account, locale matters), set
library folder and export format before the first scan.

## mac app store apps (one-time, per apple account)
`mas` only installs what the account owns. every `masApps` entry has to be
"bought" once by hand in the App Store.

## login items
the reconcile runs osascript against System Events. grant it once:
system settings > privacy & security > automation > allow your terminal (and
`darwin-rebuild`) to control **System Events**.

## background items ("allow in the background")
every nix plist runs `/bin/sh`, so macOS files them under *unknown developer* in
system settings > general > login items & extensions. one toggle there stops the
launchd agents and `org.nixos.activate-system`. symptom: ⌘Space dead after a
reboot, no sketchybar. current state:

    sfltool dumpbtm | grep -B4 disallowed

## obs virtual camera (browser streaming)
OBS mixes the cams and hands the result over as a webcam.

- system settings > general > login items & extensions, OBS, the ⓘ, camera
  extension on. restart OBS.
- privacy & security > camera and microphone for OBS, screen recording if a
  scene captures a window
- a camera belongs to one app at a time, so every cam goes into OBS

start the virtual camera in OBS *first*, then open the tab, else the browser
latches onto a wrong resolution. output 1080p30, 8 bit. brave and chrome are the
safe bet; if the camera stays missing, hardware acceleration off.

## web apps (dashboard, opentalk on this mac)
built into /Applications during `mise run deploy`. format and builder are in
**tools/web-app/README.md**. what needs a human:

- local overrides are `custom/web-apps/*/manifest.local.jsonc`
- one-time grants on first use: notifications, plus camera and mic for opentalk
  (screen recording if you share)
- `mise run web-app dmg` wants "control Finder" automation to style the
  installer window, without it the DMG is plain but works

## karabiner (umlauts + tilde)
else ä ö ü ~ stay dead:
- privacy & security > allow the karabiner system extension
- privacy & security > input monitoring > enable karabiner

check: `pgrep -f Karabiner-Core-Service`.

## aerospace (tiling wm)
- privacy & security > accessibility > enable AeroSpace

check: `aerospace list-workspaces --focused`. a config change takes after
`aerospace reload-config`.

## keyboard layout (keebwerk mega, optional)
export the VIA layout to custom/config/keyboard/keebwerk-mega.json.
