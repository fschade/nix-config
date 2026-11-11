# web-app

Turns a website into a real macOS `.app`: own icon, window, dock entry,
persistent login. A WKWebView shell with toolbar, notifications, downloads and a
real logout. Built by a Swift builder (nix cant, it needs `swiftc`), driven from
`scripts/deploy.sh`.

## Layout

```
tools/web-app/            the code
  WebAppHost.swift + ...    the shared host, split by concern
  assets/                   injected js shims + page/dmg templates
  web-app.swift             the builder + CLI
  Package.swift             dev-only, to open the host in Xcode

custom/web-apps/<slug>/   the apps (data, not code)
  manifest.jsonc            what the app is
  icon.png                  only when the manifest icon is local
```

One compiled host serves every bundle, per-app config is baked into `Info.plist`.

## Manifest

An app is a folder `custom/web-apps/<slug>/` with a `manifest.jsonc` (JSONC, `//`
allowed). No manifest = skipped. A git-ignored `manifest.local.jsonc` beside it
merges over the manifest (scalars override, `links`/`inject`/`buttons` append).

| field | required | purpose |
|---|---|---|
| `name` | ✓ | app + bundle name |
| `url` | ✓ | the start page |
| `icon` | ✓ | a local file in the folder, or a remote https url pulled at build time |
| `iconBackground` | | `"#rrggbb"` behind the artwork, for transparent corners. default white. |
| `links` | | `{ "title", "url", "section"? }`, shown as ⌘1...⌘9 and in the Links dropdown |
| `version`, `author`, `description`, `homepage` | | About panel |
| `bundleId` | | override the `com.fschade.webapp.<slug>` default |
| `userAgent` | | empty = present as full desktop Safari |
| `inspectable` | | attach from Safari > Develop. Settings toggles it live (default off). |
| `window` | | `{ "width", "height" }` (default 1100x800) |
| `toolbar` | | layout in order: `home`, `links`, `nav`, `reload`, `muteAudio`, `muteMic`, `openInBrowser`, `logout`, custom names. `"\|"` splits around the title, a nested array is one capsule. |
| `inject` | | `{ "css": [...], "js": [...] }`, a file name or `{ "file", "urlContains" }`. Main frame only. |
| `buttons` | | `{ "name", "label", "symbol"?, "symbolOn"?, "js"? or "jsFile"?, "key"? }`. `symbolOn` makes it a toggle, the scripts last expression is the state. `key` lowercase = ⌘, uppercase = ⌘⇧. |
| `allowSelfSignedCerts` | | accept invalid TLS, app hosts only (default off) |
| `keepRunningWhenClosed` | | closing the window hides it (default on) |
| `openExternalLinksInBrowser` | | off-domain http(s) clicks go to the browser, other schemes are dropped (default on) |

`custom/web-apps/example/manifest.jsonc.example` is a commented starting point.
A site shipping a PWA manifest maps over: `start_url` to `url`, `id` to
`bundleId`, `icons[].src` to `icon`, `shortcuts` to `links`.

## Building

```
mise run web-app build                       install the host's apps into /Applications
mise run web-app build <path>...             build just those app folders
mise run web-app build <path> --out <dir>    build into another dir (unregistered)
mise run web-app dmg <path>                  package one app folder as dist/<Name>.dmg
```

Without a path: builds the host's set, registers with LaunchServices and prunes
managed bundles (`.web-app-host` fingerprint) that fell out. The prune is skipped
when the wanted set is unclear, so a typo never uninstalls a working app. The
selection is always a path, never a slug.

## Per-host selection

```nix
# hosts/<host>.nix
local.webApps = [ "opentalk" "opencloud" "pushover" ];  # empty = all
```

`modules/darwin/web-apps.nix` writes it to `/etc/web-app/apps`.

## Runtime

Back/forward, reload, Overview (⌘⇧H), Open in Browser (⌘⇧B), Log Out (wipes the
session), ⌘F find, ⌘+/-/0 zoom, basic/digest auth, camera/mic for the app's own
origins.

- **Links** as ⌘1...⌘9 and a dropdown, grouped by `section`.
- **Titlebar** `App - Section - Page`, follows SPA navigation.
- **Mute toggles** (opt-in via `toolbar`): Mute Sound (⌘⇧A) silences the page,
  Mute Microphone (⌘⇧M) the mic feed. Armed before capture starts, so a room can
  be entered muted. Main frame media only, no cross-origin iframes or web-audio.
- **Downloads** land in `~/Downloads`, toolbar button with a progress ring.
- **Notifications** bridge `window.Notification` to native ones, app must run.
- **Error page** with Retry. A killed content process reloads.
- **Second windows** for scripted `window.open`, sharing session and injections.

### Page API

Every action fires a `webapp:<type>` CustomEvent on `window`, and
`window.webapp.state` mirrors the UI state.

| event | detail |
|---|---|
| `webapp:ready` | full state after every load |
| `webapp:button` | `{ name, state? }` |
| `webapp:muteAudio` / `webapp:muteMic` | `{ state }` |
| `webapp:navigate` | `{ action: "home" \| "back" \| "forward" \| "reload" }` |
| `webapp:openInBrowser`, `webapp:logout` | `{}` |
| `webapp:zoom` | `{ level }` |

`window.webapp.setButtonState(name, bool)` drives a toggle from the page. Toggle
state resets with every load. `localStorage` persists, but Log Out wipes it.

### Settings (⌘,)

The manifest is the seed. Per app and machine, UserDefaults hold start page,
links, toggles and which toolbar buttons show; only what differs from the baked
config is stored.

## Sharing a DMG

`mise run web-app dmg <path>` builds a drag-install `dist/<Name>.dmg`. Finder
does the layout, so it wants "control Finder" automation, without it the DMG is
plain but works.

Apps are ad-hoc signed, so gatekeeper blocks the first launch on another Mac:
double-click, then System Settings > Privacy & Security > "Open Anyway", or
`xattr -dr com.apple.quarantine "/Applications/<Name>.app"`.

## Development

`Package.swift` is dev-only: open `tools/web-app/` in Xcode for autocomplete. It
compiles only the host sources. Real bundles always come from `web-app.swift`.
