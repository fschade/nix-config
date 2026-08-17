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
                            Notifications/FindBar/Settings/Navigation/Downloads/
                            Audio/Inject
  assets/                   the injected js shims + page/dmg templates, stamped
                            into each bundle (Contents/Resources/assets)
  web-app.swift             the builder + CLI
  Package.swift             dev-only, to open the host in Xcode

custom/web-apps/<slug>/   the apps (data, not code)
  manifest.jsonc            what the app is
  icon.png                  only when the manifest icon is local
```

One compiled host binary serves every generated `.app`. The builder bakes
per-app config into each bundle's `Info.plist`, the host reads it at launch.

## Manifest

Each app is a folder `custom/web-apps/<slug>/` with a `manifest.jsonc`. No
manifest = skipped, so a work-in-progress folder can just sit there. Add an app
= drop a folder, remove one = delete the folder.

A git-ignored `manifest.local.jsonc` beside it is merged over the manifest
(scalars override, `links`/`inject`/`buttons` append), for room/invite links you
dont want in git.

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
| `toolbar` | | the toolbar layout, in order. Buttons: `home`, `links`, `nav`, `reload`, `muteAudio`, `muteMic`, `openInBrowser`, `logout`, plus any custom button name. `"\|"` splits left/right of the centered title (without it everything sits left), a nested array is a group whose buttons share one capsule, everything else stands alone. Default: everything except the mute toggles, custom buttons at the right end. |
| `inject` | | `{ "css": [...], "js": [...] }` page tweaks, baked in at build time. An entry is a file in the app folder or `{ "file": ..., "urlContains": ... }` to scope it to matching URLs. CSS lands at document start and follows SPA routes; JS runs once per page load if the URL matches then. Main frame only. |
| `buttons` | | custom toolbar buttons: `{ "name", "label", "symbol"?, "symbolOn"?, "js"? or "jsFile"?, "key"? }`. Click runs the JS in the page; without JS the click only fires its `webapp:button` event (see Page API). With `symbolOn` the button is a toggle: the script's last expression (a boolean) is the state, event-only toggles just flip. `key` is the menu shortcut (lowercase = ⌘, uppercase = ⌘⇧). Each button also gets a View-menu entry. |
| `allowSelfSignedCerts` | | accept self-signed / invalid TLS (default off) |
| `keepRunningWhenClosed` | | closing the window only hides it (default on) |
| `openExternalLinksInBrowser` | | off-domain clicks open in the default browser (default on) |

The layout and tweak keys in one picture:

```jsonc
{
  "name": "OpenTalk",
  "url": "https://meet.opentalk.eu/dashboard/",
  "icon": "https://meet.opentalk.eu/icon-512x512.png",

  // order as written; the mutes share one capsule, "|" splits around the title.
  // "focus" is the custom button from below.
  "toolbar": ["home", ["muteAudio", "muteMic"], "focus", "links", "|", "nav", "reload", "openInBrowser", "logout"],

  // files in the app folder, baked in at build time. the second css entry only
  // applies while the url contains "/board" (and follows spa routes).
  "inject": {
    "css": ["tweaks.css", { "file": "board.css", "urlContains": "/board" }],
    "js": ["tweaks.js"]
  },

  // a toggle button (symbolOn set): the js returns the new state as a boolean.
  // shows in the toolbar, in the View menu as ⌘⇧F, and in the Settings
  // checkboxes. an explicit "toolbar" key has to name it, as above.
  "buttons": [
    { "name": "focus", "label": "Focus Mode", "symbol": "moon", "symbolOn": "moon.fill",
      "js": "document.body.classList.toggle('focus')", "key": "F" }
  ]
}
```

Manifests are JSONC, so `//` comments are allowed.
`custom/web-apps/example/manifest.jsonc.example` is a commented starting point.

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
- **Mute toggles** (opt-in via `toolbar`, meant for call apps): **Mute Sound**
  (⌘⇧A) silences the page's audio while the call keeps running, so music from
  another app stays audible; **Mute Microphone** (⌘⇧M) mutes the mic feed into
  the page, the other side hears silence. The page's own mute UI doesn't know
  about either. Sound muting covers media elements in the main frame: no
  cross-origin iframes, and no web-audio-only sounds (notification blips), since
  suspending audio contexts would silence the mic pipeline too.
- **Page tweaks** (`inject`, `buttons`): per-app CSS/JS baked into the bundle,
  and custom toolbar buttons that run JS in the page, with optional toggle
  state. Toggle state resets with the page; a tweak that should survive reloads
  belongs in `inject.js`.
- **Downloads** land in `~/Downloads`. A toolbar button with progress ring shows
  up once you downloaded something, its popover reveals them in Finder.
- **Notifications**: WKWebView has none of its own, so the page's
  `window.Notification` is bridged to native macOS ones. Only while the app runs.
- **Error page** with a Retry button instead of a blank page.
- **App-scheme links** (`mailto:`, `tel:`, ...) go to the owning app.

### Page API

Injected JS (and the page itself) can react to the native UI. Every action
fires a `webapp:<type>` CustomEvent on `window`, and `window.webapp.state`
mirrors the current UI state:

```js
window.addEventListener('webapp:button', (e) => {
  if (e.detail.name === 'focus') document.body.classList.toggle('focus', e.detail.state);
});
window.addEventListener('webapp:ready', (e) => {
  // fires after every page load with the full state:
  // { audioMuted, micMuted, buttons: { name: bool } }
});
```

| event | detail |
|---|---|
| `webapp:ready` | full state after every load; before it, `window.webapp.state` holds defaults |
| `webapp:button` | `{ name, state? }` custom button clicked (`state` for toggles) |
| `webapp:muteAudio` / `webapp:muteMic` | `{ state }` |
| `webapp:navigate` | `{ action: "home" \| "back" \| "forward" \| "reload" }`, fired just before the navigation |
| `webapp:openInBrowser`, `webapp:logout` | `{}` (logout fires before the session wipe) |
| `webapp:zoom` | `{ level }` |

The page can drive a toggle button from its side with
`window.webapp.setButtonState(name, bool)`, so the toolbar icon follows page
state. Toggle state is not persisted: it resets with every load (`webapp:ready`
then reports `false`), restoring is the tweak's job.

For persistence plain `localStorage` works and survives app restarts (the data
store is persistent, same as cookies). One caveat: **Log Out wipes it** together
with the rest of the session.

### User agent

The apps present as full desktop Safari. WKWebView's own UA drops the
`Version/x Safari/605.1.15` token, so sites that sniff the browser (opencloud,
opentalk) flag it as unsupported even though its the same engine, the host
completes the token from the installed Safari. Set `userAgent` to override.

### Settings (⌘,)

The manifest is only the seed. Each app can edit start page, links, toggles and
which toolbar buttons show at runtime (order and grouping stay the manifest's). Edits live in UserDefaults (per app, per machine), so they arent
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
