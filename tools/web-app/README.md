# web-app

Native macOS wrappers around a website: a website becomes a real, standalone `.app`
with its own icon, window, dock entry and persistent login — a thin WKWebView shell
with a browser-like toolbar/menu, native macOS notifications, downloads, "open in
browser" and a real logout.

nix can't build these (they need `swiftc` from the Xcode command line tools), so a
small Swift builder does it, driven from `scripts/deploy.sh` during `mise run
deploy`. The only toolchain requirement is `swiftc` — no python/jq/yq.

## Layout

```
tools/web-app/                 the code (this folder)
  WebAppHost.swift + …         the shared host — one binary, split across files:
    Navigation / Toolbar /       Toolbar.swift, Menu.swift, Browser.swift,
    Menu / Browser / …           Notifications.swift, FindBar.swift, Settings.swift
  web-app.swift                the builder + CLI (compiles the host, stamps bundles)
  Package.swift                dev-only, so you can open the host in Xcode

custom/web-apps/<slug>/        the apps (data, not code)
  manifest.json                what the app is (see below)
  icon.png                     optional — only when the manifest icon is local
```

One compiled host binary serves every generated `.app`; per-app config (url, title,
links, flags) is baked into each bundle's `Info.plist` and read at launch.

## App folders + manifest

Each app is a self-contained folder `custom/web-apps/<slug>/` with a `manifest.json`.
A folder without a `manifest.json` is skipped, so a work-in-progress folder can sit
there. Add an app = drop a new folder; remove one = delete the folder (a full build
prunes the bundle it dropped).

An optional git-ignored `manifest.local.json` beside it is merged over the manifest
(scalars override, `links` append) — for secret room/invite links you don't want in
git.

### Fields

| field | required | purpose |
|---|---|---|
| `name` | ✓ | app + bundle name |
| `url` | ✓ | the start page |
| `icon` | ✓ | a local file in the folder (`"icon.png"`) **or** a remote url (`"https://…/icon.png"`) pulled at build time. never auto-detected. |
| `iconBackground` | | `"#rrggbb"` tile colour behind the artwork; set it when the icon has transparent corners (a round logo). default white. |
| `links` | | jump targets: `{ "title", "url", "section"? }`. show as ⌘1…⌘9 and in the toolbar "Links" dropdown. |
| `version` | | About panel version (default `1.0`) |
| `author` | | About panel copyright line |
| `description` | | About panel blurb |
| `homepage` | | clickable link in the About panel |
| `bundleId` | | override the `com.fschade.webapp.<slug>` default |
| `userAgent` | | custom UA string; empty = present as full desktop Safari (see below) |
| `inspectable` | | enable the Web Inspector — right-click > "Inspect Element" for the console/devtools |
| `window` | | `{ "width", "height" }` initial size (default 1100×800) |
| `allowSelfSignedCerts` | | accept self-signed / invalid TLS (default off) |
| `keepRunningWhenClosed` | | closing the window hides it, app keeps running (default on) |
| `openExternalLinksInBrowser` | | off-domain link clicks open in the default browser (default on) |

`custom/web-apps/example/manifest.json.example` shows and documents the full set —
manifests are JSONC, so `//` and `/* */` comments are allowed (copy it as a starting
point and keep the notes).

The icon is rendered into a full-bleed rounded macOS tile (cover-scaled artwork on
the `iconBackground`), then the standard `.icns` sizes. A **remote** icon is handy
to lift a site's own icon straight from its PWA manifest without committing
third-party artwork — e.g. opencloud and opentalk pull theirs from the live site.

### Lifting from a PWA manifest

Many sites ship a `manifest.json` (web app manifest) you can copy fields from:

| PWA member | manifest field |
|---|---|
| `name`, `description`, `start_url` | `name`, `description`, `url` |
| `id` | `bundleId` |
| `icons[].src` | `icon` (use the remote url directly) |
| `shortcuts` | `links` |
| `theme_color` / `background_color` | ≈ `iconBackground` |

`display`, `orientation`, `categories`, `scope` don't translate to a native wrapper.

## Building — `mise run web-app <command>`

```
mise run web-app build                        install the host's apps into /Applications
mise run web-app build <path>...              build just those app folders (by path)
mise run web-app build <path> --out <dir>     build into another dir (external, unregistered)
mise run web-app dmg <path>                   package one app folder as dist/<Name>.dmg
```

`build` with no path is the deploy path: it builds the host's managed set (see below)
into `/Applications`, registers them with LaunchServices, and prunes managed bundles
(marked with a `.web-app-host` fingerprint, so foreign apps are never touched) that
fell out of the config. A `build <path>` builds exactly those folders, no prune —
the selection is **always a path**, never a slug lookup. `--out` defaults to
`/Applications` (the install); point it elsewhere to produce a plain, unregistered
`.app` (e.g. to hand off without a DMG).

Sessions persist across launches; after editing a manifest or icon, just build again
(or `mise run deploy`).

## Per-host selection (declarative)

By default a host builds every app in `custom/web-apps/`. To restrict a host to a
subset, list the slugs in its nix config:

```nix
# hosts/<host>.nix
local.webApps = [ "opentalk" "opencloud" "pushover" ];  # empty = all
```

`modules/darwin/web-apps.nix` writes the resolved list to `/etc/web-app/apps`; a full
`build` builds exactly that set and prunes the rest. Source of truth stays in nix.

## Runtime features

Every window has a browser-like toolbar and a **Go** menu: back/forward, reload,
**Overview** (⌘⇧H), **Open in Browser** (⌘⇧B — the current page in the default
browser, handy for a password manager) and **Log Out** (wipes the app's session).

- **Links dropdown** — the manifest `links` as ⌘1…⌘9 and a toolbar dropdown. The
  dropdown only appears when it adds something: hidden for zero links, or a lone
  link that just points home.
- **Sections** — give links a `section` and they group under a heading in the
  dropdown and Go menu. Ordering drives grouping (consecutive same-section links sit
  together); ⌘1…⌘9 still run linearly. Handy when one app fronts several sites.
- **Titlebar** — centered, shows `App — Section — Page`. The section only appears
  when the app has more than one (a lone section is noise). The page comes from the
  matching link, else the page's `<title>` with the app name stripped. Updates live
  through SPA navigation. With sections, ⌘⇧H jumps to the current section's home.
- **About panel** — fed from the manifest metadata (version, author, description,
  clickable homepage).
- **Load progress** — a thin bar under the toolbar.
- **Downloads** — land in `~/Downloads`. A Safari-style toolbar button (with a
  progress ring) appears once you've downloaded something and opens a popover
  listing them — each with the file icon, status and a stop / reveal-in-Finder
  button. A download that interrupts a page load is not treated as an error.
- **Error page** — a failed load (network down, bad cert) shows an inline message
  with a Retry button instead of a blank page.
- **App-scheme links** — `mailto:` / `tel:` / `facetime:` … are handed to the
  owning app instead of dead-ending.
- **Find** ⌘F, **Zoom** ⌘+/−/0, **camera/mic** granted to the page (macOS TCC still
  gates it), **http basic/digest auth** like a browser (prompt once, keychain).
- **Notifications** — WKWebView has none of its own, so the page's
  `window.Notification` is bridged to native macOS notifications (works while the
  app runs — e.g. pushover autostarts via a login item).

### User agent

By default the apps present as full desktop Safari. WKWebView's own UA drops the
`Version/x Safari/605.1.15` token real Safari sends, so sites that sniff the browser
(opencloud, opentalk) flag it as old/unsupported even though it's the same engine —
the host completes the token from the installed Safari's version. Set `userAgent` in
the manifest to override (e.g. a Chrome string) for sites that specifically want
Chrome.

### Settings (⌘,)

The manifest is only the seed. Each app has a Settings window to edit the start
page, the links (title / section / url, drag to reorder) and the toggles (self-signed
certs, keep running, external links) at runtime. Edits live in UserDefaults (per
app, per machine), so they aren't versioned. Self-signed / invalid TLS is rejected
unless you turn it on here (or set `allowSelfSignedCerts` in the manifest) — only for
something you trust, e.g. a homelab box.

## Sharing — the DMG

`mise run web-app dmg <path>` packages one app folder as a drag-install `dist/<Name>.dmg`
(git-ignored): a clean white installer window with the `.app` on the left, an
`/Applications` shortcut on the right and a "Read me first" note. Finder applies the
layout, so the first run wants **"control Finder"** (System Settings > Privacy &
Security > Automation) — grant it, or it warns and ships a plain (still working) DMG.
(The layout is written under a throwaway volume name and the volume then renamed, so
Finder's per-name window-state cache can't stop a rebuilt DMG from restyling.)

The apps are ad-hoc signed (no Apple developer id), so gatekeeper blocks the first
launch on another Mac. The recipient double-clicks once, then System Settings >
Privacy & Security > "Open Anyway" (right-click > Open no longer works since
Sequoia), or `xattr -dr com.apple.quarantine "/Applications/<Name>.app"`. One-time
per app. A warning-free handoff would need a paid developer id + notarisation, which
we don't do.

## Development

`Package.swift` is dev-only: open `tools/web-app/` in Xcode (or `swift build`) to
edit the host with autocomplete/debugging. It compiles only the host sources;
`web-app.swift` (the builder script) is excluded. The real bundles are always built
by `web-app.swift` via `swiftc`, not by this package.
