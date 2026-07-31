# web-app

Turns a website into a real macOS `.app`: own icon, window, dock entry,
persistent login. A thin WKWebView shell with a browser-like toolbar, native
notifications, downloads and a real logout.

Nix cant build these (they need `swiftc` from the Xcode command line tools), so
a small Swift builder does it, driven from `scripts/deploy.sh` on `mise run
deploy`. Only requirement is `swiftc`, no python/jq/yq.

## Layout

```
tools/web-app/            the code
  WebAppHost.swift + ...    the shared host, split over Toolbar/Menu/Browser/
                            Notifications/FindBar/Settings/Navigation/Downloads
  web-app.swift             the builder + CLI
  Package.swift             dev-only, to open the host in Xcode

custom/web-apps/<slug>/   the apps (data, not code)
  manifest.json             what the app is
  icon.png                  only when the manifest icon is local
```

One compiled host binary serves every generated `.app`. The builder bakes
per-app config into each bundle's `Info.plist`, the host reads it at launch.

## Manifest

Each app is a folder `custom/web-apps/<slug>/` with a `manifest.json`. No
manifest = skipped, so a work-in-progress folder can just sit there. Add an app
= drop a folder, remove one = delete the folder.

A git-ignored `manifest.local.json` beside it is merged over the manifest
(scalars override, `links` append), for room/invite links you dont want in git.

| field | required | purpose |
|---|---|---|
| `name` | ✓ | app + bundle name |
| `url` | ✓ | the start page |
| `icon` | ✓ | a local file in the folder (`"icon.png"`) **or** a remote https url pulled at build time. never auto-detected. |
| `iconBackground` | | `"#rrggbb"` tile colour behind the artwork, for icons with transparent corners. default white. |
| `links` | | jump targets: `{ "title", "url", "section"? }`. show as ⌘1...⌘9 and in the toolbar "Links" dropdown. |
| `version` | | About panel version (default `1.0`) |
| `author` | | About panel copyright line |
| `description` | | About panel blurb |
| `homepage` | | clickable link in the About panel |
| `bundleId` | | override the `com.fschade.webapp.<slug>` default |
| `userAgent` | | custom UA string, empty = present as full desktop Safari |
| `inspectable` | | enable the Web Inspector (right-click > Inspect Element) |
| `window` | | `{ "width", "height" }` initial size (default 1100x800) |
| `allowSelfSignedCerts` | | accept self-signed / invalid TLS (default off) |
| `keepRunningWhenClosed` | | closing the window only hides it (default on) |
| `openExternalLinksInBrowser` | | off-domain clicks open in the default browser (default on) |

Manifests are JSONC, so `//` comments are allowed.
`custom/web-apps/example/manifest.json.example` is a commented starting point.

A remote `icon` is handy to lift a site's own icon from its PWA manifest without
committing third-party artwork (opencloud and opentalk do that). The builder
renders it into a full-bleed rounded macOS tile, then the standard `.icns` sizes.

Sites that ship a PWA manifest map over nicely: `name`/`description`/`start_url`
become `name`/`description`/`url`, `id` becomes `bundleId`, `icons[].src` becomes
`icon`, `shortcuts` becomes `links`, and `theme_color` roughly maps to
`iconBackground`.

## Building

```
mise run web-app build                       install the host's apps into /Applications
mise run web-app build <path>...             build just those app folders
mise run web-app build <path> --out <dir>    build into another dir (unregistered)
mise run web-app dmg <path>                  package one app folder as dist/<Name>.dmg
```

`build` without a path is the deploy path: builds the host's set, registers them
with LaunchServices and prunes managed bundles that fell out of the config.
Managed bundles carry a `.web-app-host` fingerprint, foreign apps are never
touched. The prune is skipped whenever the wanted set is unclear (an entry that
matches no folder, a manifest that wont parse), so a typo never uninstalls a
working app. With a path it builds exactly those folders and prunes nothing, the
selection is **always a path**, never a slug lookup.

Every build assembles off to the side and only swaps the bundle in once it
signed, so a build that dies halfway (a dead icon url, codesign saying no)
leaves the working install in place.

Sessions persist across launches, so after editing a manifest or icon just build
again.

## Per-host selection

By default a host builds every app in `custom/web-apps/`. To restrict it:

```nix
# hosts/<host>.nix
local.webApps = [ "opentalk" "opencloud" "pushover" ];  # empty = all
```

`modules/darwin/web-apps.nix` writes the resolved list to `/etc/web-app/apps`.
Source of truth stays in nix.

## Runtime

Toolbar and **Go** menu: back/forward, reload, **Overview** (⌘⇧H), **Open in
Browser** (⌘⇧B, handy for a password manager) and **Log Out** (wipes the
session). Plus ⌘F find, ⌘+/-/0 zoom, http basic/digest auth like a browser,
camera/mic for the app's own origins (macOS TCC still gates it).

- **Links** show as ⌘1...⌘9 and a toolbar dropdown. The dropdown hides when it
  would add nothing (zero links, or one link pointing home). Give links a
  `section` and they group under headings, handy when one app fronts several
  sites.
- **Titlebar** shows `App — Section — Page`, updates through SPA navigation. The
  section only appears when the app has more than one.
- **Downloads** land in `~/Downloads`. A toolbar button with progress ring shows
  up once you downloaded something, its popover reveals them in Finder.
- **Notifications**: WKWebView has none of its own, so the page's
  `window.Notification` is bridged to native macOS ones. Only while the app runs.
- **Error page** with a Retry button instead of a blank page.
- **App-scheme links** (`mailto:`, `tel:`, ...) go to the owning app.

### User agent

The apps present as full desktop Safari. WKWebView's own UA drops the
`Version/x Safari/605.1.15` token, so sites that sniff the browser (opencloud,
opentalk) flag it as unsupported even though its the same engine, the host
completes the token from the installed Safari. Set `userAgent` to override.

### Settings (⌘,)

The manifest is only the seed. Each app can edit start page, links and toggles
at runtime. Edits live in UserDefaults (per app, per machine), so they arent
versioned, and each app only stores what differs from the baked config, so
manifest changes keep shining through. Self-signed TLS is only ever accepted
for the app's own hosts (start page + links), never for third-party origins.

## Sharing a DMG

`mise run web-app dmg <path>` builds a drag-install `dist/<Name>.dmg`
(git-ignored) with the `.app`, an `/Applications` shortcut and a "Read me first"
note. Finder does the layout, so the first run wants **"control Finder"**
(System Settings > Privacy & Security > Automation), without it you still get a
plain, working DMG.

The apps are ad-hoc signed (no Apple developer id), so gatekeeper blocks the
first launch on another Mac: double-click once, then System Settings > Privacy &
Security > "Open Anyway" (right-click > Open stopped working with Sequoia), or
`xattr -dr com.apple.quarantine "/Applications/<Name>.app"`. One-time per app. A
warning-free handoff would need a paid developer id + notarisation.

## Development

`Package.swift` is dev-only: open `tools/web-app/` in Xcode (or `swift build`)
for autocomplete and debugging. It compiles only the host sources, not
`web-app.swift`. Real bundles are always built by `web-app.swift` via `swiftc`.
