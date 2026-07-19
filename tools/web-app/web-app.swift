#!/usr/bin/env swift
#if os(macOS)
import AppKit

// The web-app builder. One Swift entrypoint, run with `swift web-app.swift <cmd>`:
// it compiles the shared WKWebView host (WebAppHost.swift + Settings.swift) with
// swiftc, then stamps .app bundles from self-contained app folders. Each folder
// holds a manifest.json (name, url, optional links/flags/iconBackground) and an
// icon.png beside it, so a folder is portable — point the builder at any folder.
// Pure Swift/Foundation for the config + Info.plist; only shells out to
// always-present macOS tools (swiftc/sips/iconutil/codesign/lsregister/hdiutil).
//
//   web-app.swift build [<path>...] [--out <dir>]
//                                           build apps; default --out is /Applications
//                                           (the install). no path = the host's managed
//                                           set from custom/web-apps (allowlist + prune);
//                                           a path builds just that folder, no prune.
//                                           --out elsewhere = an external, unregistered .app.
//   web-app.swift dmg <path>                package one app folder as dist/<Name>.dmg
//
// Managed apps live in custom/web-apps/<slug>/. A full `build` (no slug) builds the
// per-host allowlist from /etc/web-app/apps (written by modules/darwin/web-apps.nix
// from local.webApps); an empty file means "every app". Managed bundles that fall
// out of that set are pruned (foreign apps, without our marker, are never touched).

let fm = FileManager.default
let env = ProcessInfo.processInfo.environment
let argv = CommandLine.arguments

func warn(_ s: String) { FileHandle.standardError.write((s + "\n").data(using: .utf8)!) }
func die(_ s: String) -> Never { warn(s); exit(2) }

// locate the repo: honour mise's project root, else walk up from this script
let scriptDir = URL(fileURLWithPath: argv[0]).deletingLastPathComponent()
let root = env["MISE_PROJECT_ROOT"].map { URL(fileURLWithPath: $0) }
    ?? scriptDir.deletingLastPathComponent().deletingLastPathComponent()
let webappsDir = root.appendingPathComponent("custom/web-apps").path
let hereDir = scriptDir.path // where WebAppHost.swift + Settings.swift live
let allowlistFile = "/etc/web-app/apps"

let marker = ".web-app-host" // our fingerprint, so cleanup never touches foreign apps
let lsregister = "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

@discardableResult
func shell(_ tool: String, _ a: [String], quiet: Bool = true) -> Int32 {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: tool)
    p.arguments = a
    if quiet { p.standardOutput = FileHandle.nullDevice; p.standardError = FileHandle.nullDevice }
    do { try p.run() } catch { return -1 }
    p.waitUntilExit()
    return p.terminationStatus
}

// MARK: config model

struct Link: Codable { let title: String; let url: String; let section: String? }
struct AppConfig: Codable {
    var name: String?
    var url: String?
    var icon: String?           // optional; defaults to icon.png beside the manifest
    var iconBackground: String? // optional #rrggbb; else white (source art fills the tile)
    var links: [Link]?
    var allowSelfSignedCerts: Bool? // opt-in: accept self-signed/invalid tls for this app
    var keepRunningWhenClosed: Bool? // closing the window hides it, app keeps running (e.g. pushover)
    var openExternalLinksInBrowser: Bool? // off-domain link clicks open in the default browser
    // metadata — identity + about panel
    var version: String?     // -> CFBundleShortVersionString (default "1.0")
    var author: String?      // -> NSHumanReadableCopyright, shown in About
    var description: String? // -> a blurb in the About panel
    var homepage: String?    // -> a clickable link in the About panel
    var bundleId: String?    // -> CFBundleIdentifier (default com.fschade.webapp.<slug>)
    var userAgent: String?   // -> WKWebView.customUserAgent (e.g. to look like Chrome)
    var inspectable: Bool?   // -> enable the Web Inspector (right-click > Inspect Element)
    var window: WindowSize?  // -> initial window size (default 1100x800)
}

struct WindowSize: Codable {
    var width: Double?
    var height: Double?
}

// strip // line and /* */ block comments so a manifest can be documented inline
// (JSONC). string-aware, so the // in "https://…" and the like survive.
func stripJSONC(_ s: String) -> String {
    var out = "", inString = false, escaped = false
    let chars = Array(s)
    var i = 0
    while i < chars.count {
        let c = chars[i]
        if inString {
            out.append(c)
            if escaped { escaped = false } else if c == "\\" { escaped = true } else if c == "\"" { inString = false }
            i += 1
        } else if c == "\"" {
            inString = true; out.append(c); i += 1
        } else if c == "/", i + 1 < chars.count, chars[i + 1] == "/" {
            i += 2; while i < chars.count, chars[i] != "\n" { i += 1 }
        } else if c == "/", i + 1 < chars.count, chars[i + 1] == "*" {
            i += 2; while i + 1 < chars.count, !(chars[i] == "*" && chars[i + 1] == "/") { i += 1 }; i += 2
        } else {
            out.append(c); i += 1
        }
    }
    return out
}

func load(_ path: String) -> AppConfig? {
    guard let raw = try? String(contentsOfFile: path, encoding: .utf8) else { return nil }
    let data = Data(stripJSONC(raw).utf8)
    do { return try JSONDecoder().decode(AppConfig.self, from: data) } catch {
        warn("web-app: cannot parse \(path): \(error)")
        return nil
    }
}

func slugify(_ s: String) -> String {
    String(s.lowercased().unicodeScalars.filter {
        ($0 >= "a" && $0 <= "z") || ($0 >= "0" && $0 <= "9")
    })
}

// MARK: icon rendering

// draw everything in sRGB so the background colour matches the (sRGB) artwork
// exactly — a device-rgb context would shift the colours and leave a faint ring.
let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!

// "#rrggbb" (or "rrggbb") -> colour. white if unset/malformed, so a source that
// already fills the tile just ignores it. set iconBackground in the manifest when
// the artwork has transparent corners (e.g. a round logo) that should blend in.
func background(_ hex: String?) -> CGColor {
    let white = CGColor(colorSpace: sRGB, components: [1, 1, 1, 1])!
    guard var s = hex else { return white }
    if s.hasPrefix("#") { s.removeFirst() }
    guard s.count == 6, let value = Int(s, radix: 16) else { return white }
    let red = Double((value >> 16) & 0xff), green = Double((value >> 8) & 0xff), blue = Double(value & 0xff)
    return CGColor(colorSpace: sRGB, components: [red / 255, green / 255, blue / 255, 1]) ?? white
}

// Render a full-bleed macOS-style app icon: fill the rounded tile with the
// background colour, then draw the artwork on top scaled to cover it.
func renderIcon(source: String, background bg: CGColor, to output: String) -> Bool {
    let side = 1024
    guard let image = NSImage(contentsOfFile: source),
          let art = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
          let ctx = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8,
                              bytesPerRow: 0, space: sRGB,
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }

    let tile = CGRect(x: 0, y: 0, width: side, height: side)
    let corner = CGFloat(side) * 0.2237 // apple's continuous-corner ratio
    ctx.addPath(CGPath(roundedRect: tile, cornerWidth: corner, cornerHeight: corner, transform: nil))
    ctx.clip()
    ctx.setFillColor(bg)
    ctx.fill(tile)

    let scale = max(CGFloat(side) / CGFloat(art.width), CGFloat(side) / CGFloat(art.height))
    let w = CGFloat(art.width) * scale, h = CGFloat(art.height) * scale
    ctx.draw(art, in: CGRect(x: (CGFloat(side) - w) / 2, y: (CGFloat(side) - h) / 2, width: w, height: h))

    guard let rendered = ctx.makeImage(),
          let png = NSBitmapImageRep(cgImage: rendered).representation(using: .png, properties: [:]) else { return false }
    return (try? png.write(to: URL(fileURLWithPath: output))) != nil
}

func buildIcon(source: String, background bg: CGColor, into bundle: String, slug: String) {
    let base = NSTemporaryDirectory() + "webapp-\(slug)-\(UUID().uuidString)"
    let iconset = base + ".iconset"
    let master = base + ".png"
    try? fm.createDirectory(atPath: iconset, withIntermediateDirectories: true)
    defer { try? fm.removeItem(atPath: iconset); try? fm.removeItem(atPath: master) }
    guard renderIcon(source: source, background: bg, to: master) else {
        warn("web-app: could not render icon from \(source)")
        return
    }
    for s in [16, 32, 128, 256, 512] {
        shell("/usr/bin/sips", ["-z", "\(s)", "\(s)", master, "--out", "\(iconset)/icon_\(s)x\(s).png"])
        let d = s * 2
        shell("/usr/bin/sips", ["-z", "\(d)", "\(d)", master, "--out", "\(iconset)/icon_\(s)x\(s)@2x.png"])
    }
    shell("/usr/bin/iconutil", ["-c", "icns", iconset, "-o", "\(bundle)/Contents/Resources/icon.icns"])
}

// MARK: host + bundle building

// compile the shared WKWebView host once into a temp dir; every bundle copies it.
// the host is every .swift next to this script except the script itself, so new
// source files (the AppDelegate is split across several) are picked up on their own.
func compileHost() -> String {
    let out = NSTemporaryDirectory() + "WebAppHost-\(UUID().uuidString)"
    let notHost: Set<String> = ["web-app.swift", "Package.swift"] // the builder + the dev manifest
    let sources = ((try? fm.contentsOfDirectory(atPath: hereDir)) ?? [])
        .filter { $0.hasSuffix(".swift") && !notHost.contains($0) }
        .sorted()
        .map { "\(hereDir)/\($0)" }
    guard !sources.isEmpty else { die("web-app: no host sources in \(hereDir)") }
    print("compiling web-app host…")
    let status = shell("/usr/bin/swiftc", ["-O"] + sources + [
        "-o", out, "-framework", "Cocoa", "-framework", "WebKit", "-framework", "UserNotifications",
    ], quiet: false)
    guard status == 0 else { die("web-app: host compile failed (swiftc exit \(status))") }
    return out
}

// resolve the manifest icon reference to a readable file: a remote http(s) url is
// downloaded to a temp file (so no third-party artwork needs committing), a local
// ref is taken relative to the app folder. never auto-detected.
func resolveIcon(_ ref: String, appDir: String) -> String? {
    if ref.hasPrefix("http://") || ref.hasPrefix("https://") {
        guard let url = URL(string: ref), let data = try? Data(contentsOf: url) else {
            warn("web-app: could not download icon \(ref)")
            return nil
        }
        let ext = (ref as NSString).pathExtension
        let tmp = NSTemporaryDirectory() + "webapp-icon-\(UUID().uuidString)" + (ext.isEmpty ? "" : ".\(ext)")
        return (try? data.write(to: URL(fileURLWithPath: tmp))) != nil ? tmp : nil
    }
    let path = "\(appDir)/\(ref)"
    return fm.fileExists(atPath: path) ? path : nil
}

// Build one self-contained app folder into <outDir>/<Name>.app. Returns the bundle
// name on success (for the built set + prune), nil if skipped.
func buildApp(from appDir: String, hostBin: String, into outDir: String, register: Bool) -> String? {
    let manifest = "\(appDir)/manifest.json"
    guard var cfg = load(manifest) else {
        warn("web-app: no manifest.json in \(appDir) — skipping")
        return nil
    }
    if let ov = load("\(appDir)/manifest.local.json") {
        if let v = ov.name { cfg.name = v }
        if let v = ov.url { cfg.url = v }
        if let v = ov.icon { cfg.icon = v }
        if let v = ov.iconBackground { cfg.iconBackground = v }
        if let v = ov.links { cfg.links = (cfg.links ?? []) + v }
        if let v = ov.version { cfg.version = v }
        if let v = ov.author { cfg.author = v }
        if let v = ov.description { cfg.description = v }
        if let v = ov.homepage { cfg.homepage = v }
        if let v = ov.bundleId { cfg.bundleId = v }
        if let v = ov.userAgent { cfg.userAgent = v }
        if let v = ov.inspectable { cfg.inspectable = v }
        if let v = ov.window { cfg.window = v }
    }
    guard let name = cfg.name, let url = cfg.url, let iconRef = cfg.icon else {
        warn("web-app: \(manifest) needs name, url and icon — skipping")
        return nil
    }
    // the icon comes only from the manifest (never auto-detected): a path relative
    // to the app folder, or a remote http(s) url pulled at build time.
    guard let iconPath = resolveIcon(iconRef, appDir: appDir) else {
        warn("web-app: \(name): icon \(iconRef) not available — skipping")
        return nil
    }

    let slug = slugify(name)
    let bundle = "\(outDir)/\(name).app"
    print("building \(name) → \(bundle)")

    try? fm.removeItem(atPath: bundle)
    do {
        try fm.createDirectory(atPath: "\(bundle)/Contents/MacOS", withIntermediateDirectories: true)
        try fm.createDirectory(atPath: "\(bundle)/Contents/Resources", withIntermediateDirectories: true)
        try fm.copyItem(atPath: hostBin, toPath: "\(bundle)/Contents/MacOS/WebAppHost")
    } catch {
        warn("web-app: \(name): \(error)")
        return nil
    }

    buildIcon(source: iconPath, background: background(cfg.iconBackground), into: bundle, slug: slug)

    var info: [String: Any] = [
        "CFBundleName": name,
        "CFBundleDisplayName": name,
        "CFBundleExecutable": "WebAppHost",
        "CFBundleIdentifier": cfg.bundleId ?? "com.fschade.webapp.\(slug)",
        "CFBundleIconFile": "icon",
        "CFBundlePackageType": "APPL",
        "CFBundleShortVersionString": cfg.version ?? "1.0",
        "CFBundleVersion": cfg.version ?? "1",
        "LSMinimumSystemVersion": "13.0",
        "NSHighResolutionCapable": true,
        "WebAppURL": url,
        "NSCameraUsageDescription": "\(name) may use the camera for calls.",
        "NSMicrophoneUsageDescription": "\(name) may use the microphone for calls.",
        "WebAppAllowSelfSignedCerts": cfg.allowSelfSignedCerts ?? false,
        "WebAppKeepRunning": cfg.keepRunningWhenClosed ?? true,
        "WebAppExternalLinksInBrowser": cfg.openExternalLinksInBrowser ?? true,
    ]
    // optional metadata — only stamped when the manifest sets it
    if let v = cfg.author, !v.isEmpty { info["NSHumanReadableCopyright"] = v }
    if let v = cfg.description, !v.isEmpty { info["WebAppDescription"] = v }
    if let v = cfg.homepage, !v.isEmpty { info["WebAppHomepage"] = v }
    if let v = cfg.userAgent, !v.isEmpty { info["WebAppUserAgent"] = v }
    if cfg.inspectable == true { info["WebAppInspectable"] = true }
    if let w = cfg.window?.width { info["WebAppWindowWidth"] = w }
    if let h = cfg.window?.height { info["WebAppWindowHeight"] = h }
    if let links = cfg.links, !links.isEmpty {
        info["WebAppMenu"] = links.map { link -> [String: String] in
            var m = ["title": link.title, "url": link.url]
            if let s = link.section, !s.isEmpty { m["section"] = s } // optional group heading
            return m
        }
    }
    guard let plist = try? PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0) else {
        warn("web-app: \(name): could not serialize Info.plist")
        return nil
    }
    fm.createFile(atPath: "\(bundle)/Contents/Info.plist", contents: plist)

    fm.createFile(atPath: "\(bundle)/Contents/Resources/\(marker)", contents: nil)
    shell("/usr/bin/codesign", ["--force", "--deep", "--sign", "-", bundle])
    // refresh LaunchServices so open/Dock/login-item see the rebuilt bundle
    if register { shell(lsregister, ["-f", bundle]) }
    return "\(name).app"
}

// managed app folders: subdirs of custom/web-apps/ that carry a manifest.json.
func managedFolders() -> [String] {
    guard let entries = try? fm.contentsOfDirectory(atPath: webappsDir) else {
        warn("web-app: no app root at \(webappsDir)")
        return []
    }
    return entries.sorted().filter { folder in
        var isDir: ObjCBool = false
        return fm.fileExists(atPath: "\(webappsDir)/\(folder)", isDirectory: &isDir) && isDir.boolValue
            && fm.fileExists(atPath: "\(webappsDir)/\(folder)/manifest.json")
    }
}

// the per-host allowlist file: one slug per line, empty/absent = build everything.
func hostAllowlist() -> Set<String> {
    guard let text = try? String(contentsOfFile: allowlistFile, encoding: .utf8) else { return [] }
    return Set(text.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
        .filter { !$0.isEmpty })
}

// remove managed bundles (marked with our fingerprint) that we didn't just build.
func prune(builtNames: Set<String>, in dir: String) {
    guard let entries = try? fm.contentsOfDirectory(atPath: dir) else { return }
    for e in entries where e.hasSuffix(".app") {
        let m = "\(dir)/\(e)/Contents/Resources/\(marker)"
        if fm.fileExists(atPath: m), !builtNames.contains(e) {
            print("removing stale \(e)")
            try? fm.removeItem(atPath: "\(dir)/\(e)")
        }
    }
}

// does folder/app match one of the given slugs (folder name or slugified app name)?
func matches(folder: String, filters: Set<String>) -> Bool {
    if filters.contains(folder.lowercased()) { return true }
    let name = load("\(webappsDir)/\(folder)/manifest.json")?.name ?? folder
    return filters.contains(slugify(name))
}

// an arg is a path (not a slug) when it points at a directory that holds a
// manifest.json — so `build ~/some/app` and `build opentalk` both just work.
func isAppFolder(_ path: String) -> Bool {
    var isDir: ObjCBool = false
    return fm.fileExists(atPath: "\(path)/manifest.json")
        && fm.fileExists(atPath: path, isDirectory: &isDir) && isDir.boolValue
}

// MARK: commands

func cmdBuild(_ args: [String]) {
    // paths + optional --out (default /Applications, the install location)
    var paths: [String] = []
    var outDir = "/Applications"
    var i = 0
    while i < args.count {
        if args[i] == "--out" {
            guard i + 1 < args.count else { die("web-app: --out needs a directory") }
            outDir = args[i + 1]; i += 2
        } else if args[i].hasPrefix("-") {
            die("web-app: unknown flag \(args[i])")
        } else {
            paths.append(args[i]); i += 1
        }
    }
    try? fm.createDirectory(atPath: outDir, withIntermediateDirectories: true)
    let register = outDir == "/Applications" // LaunchServices only makes sense there

    let host = compileHost()
    defer { try? fm.removeItem(atPath: host) }
    var built = Set<String>()

    // no path: build the host's managed set (allowlist governs) and prune apps that
    // fell out of it — the deploy path. an --out elsewhere just relocates that set.
    if paths.isEmpty {
        let filters = hostAllowlist()
        for folder in managedFolders() where filters.isEmpty || matches(folder: folder, filters: filters) {
            if let name = buildApp(from: "\(webappsDir)/\(folder)", hostBin: host, into: outDir, register: register) {
                built.insert(name)
            }
        }
        prune(builtNames: built, in: outDir)
        print("done: \(built.sorted().joined(separator: " "))")
        return
    }

    // explicit paths → build exactly those folders, no prune (the rest stay put)
    for path in paths {
        guard isAppFolder(path) else {
            warn("web-app: \(path) is not an app folder (no manifest.json) — skipping")
            continue
        }
        if let name = buildApp(from: path, hostBin: host, into: outDir, register: register) { built.insert(name) }
    }
    if built.isEmpty { die("web-app: no app folder built from \(paths.joined(separator: ", "))") }
    print("done: \(built.sorted().joined(separator: " "))")
}

// The DMG window size in points, and where the two icons sit inside it (Finder's
// top-left origin). The background image matches the window content pixel-for-point.
private let dmgSize = NSSize(width: 640, height: 510)
private let dmgAppPos = NSPoint(x: 170, y: 190)    // the .app icon
private let dmgAppsPos = NSPoint(x: 470, y: 190)   // the Applications shortcut
private let dmgReadmePos = NSPoint(x: 320, y: 350) // the first-launch read-me, below

// The DMG backdrop is plain white (see below); Finder positions the app, the
// Applications shortcut and the read-me on top.
func renderDMGBackground(iconPath: String, to output: String) -> Bool {
    // draw into an explicit bitmap at exactly the point size, so a retina screen
    // doesn't render it at 2x and throw off the window/background alignment.
    guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(dmgSize.width),
                                     pixelsHigh: Int(dmgSize.height), bitsPerSample: 8,
                                     samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                     colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
          let ctx = NSGraphicsContext(bitmapImageRep: rep) else { return false }
    // draw straight through Core Graphics — the higher-level AppKit path/image draw
    // doesn't reliably render into a bare bitmap context. CG origin is bottom-left.
    let cg = ctx.cgContext

    cg.setFillColor(NSColor.white.cgColor)
    cg.fill(CGRect(origin: .zero, size: dmgSize))

    // a faint, centred logo watermark. the icon is a filled tile (art on a coloured
    // square), so draw it larger than the canvas — the square edges bleed off and
    // only the centred logo + a whisper of tint remain (no visible box).
    if let icon = NSImage(contentsOfFile: iconPath),
       let cgImage = icon.cgImage(forProposedRect: nil, context: nil, hints: nil) {
        cg.saveGState()
        cg.setAlpha(0.05)
        let s = dmgSize.width
        cg.draw(cgImage, in: CGRect(x: (dmgSize.width - s) / 2, y: (dmgSize.height - s) / 2, width: s, height: s))
        cg.restoreGState()
    }

    // finder's y is top-down; flip it to CG's bottom-up
    let appC = CGPoint(x: dmgAppPos.x, y: dmgSize.height - dmgAppPos.y)
    let appsC = CGPoint(x: dmgAppsPos.x, y: dmgSize.height - dmgAppsPos.y)
    let box: CGFloat = 150

    // dashed "drop here" frames around the two icon slots
    cg.setLineWidth(2)
    cg.setStrokeColor(NSColor(calibratedWhite: 0.4, alpha: 0.3).cgColor)
    cg.setLineDash(phase: 0, lengths: [6, 5])
    for c in [appC, appsC] {
        cg.addPath(CGPath(roundedRect: CGRect(x: c.x - box / 2, y: c.y - box / 2, width: box, height: box),
                          cornerWidth: 20, cornerHeight: 20, transform: nil))
        cg.strokePath()
    }

    // solid arrow from the app frame toward Applications
    cg.setLineDash(phase: 0, lengths: [])
    cg.setLineCap(.round)
    cg.setLineJoin(.round)
    cg.setStrokeColor(NSColor(calibratedWhite: 0.4, alpha: 0.55).cgColor)
    let tip = CGPoint(x: appsC.x - box / 2 - 12, y: appC.y)
    cg.move(to: CGPoint(x: appC.x + box / 2 + 12, y: appC.y))
    cg.addLine(to: tip)
    cg.strokePath()
    cg.move(to: CGPoint(x: tip.x - 12, y: tip.y + 8))
    cg.addLine(to: tip)
    cg.addLine(to: CGPoint(x: tip.x - 12, y: tip.y - 8))
    cg.strokePath()

    guard let png = rep.representation(using: .png, properties: [:]) else { return false }
    return (try? png.write(to: URL(fileURLWithPath: output))) != nil
}

// like shell(), but captures stdout (to read hdiutil's mount point) and stderr
// (to surface the real osascript error instead of guessing).
func shellOutput(_ tool: String, _ a: [String]) -> (status: Int32, out: String, err: String) {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: tool)
    p.arguments = a
    let outPipe = Pipe(), errPipe = Pipe()
    p.standardOutput = outPipe
    p.standardError = errPipe
    do { try p.run() } catch { return (-1, "", "\(error)") }
    let out = outPipe.fileHandleForReading.readDataToEndOfFile()
    let err = errPipe.fileHandleForReading.readDataToEndOfFile()
    p.waitUntilExit()
    return (p.terminationStatus, String(data: out, encoding: .utf8) ?? "", String(data: err, encoding: .utf8) ?? "")
}

// Lay out the mounted volume via Finder: hide the chrome, set the window + icon
// size, drop the background picture and place the two icons on their frames.
// Best-effort — if it can't (e.g. no "control Finder" automation grant), the real
// error is printed and the dmg ships plain.
func styleDMG(volume: String, appFile: String, bgName: String, readme: String) {
    // relative HFS reference for the background so it stays valid after the volume
    // is renamed (a POSIX/absolute path would point at the throwaway mount).
    let script = """
    tell application "Finder"
      tell disk "\(volume)"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {300, 160, \(300 + Int(dmgSize.width)), \(160 + Int(dmgSize.height) + 28)}
        set opts to the icon view options of container window
        set arrangement of opts to not arranged
        set icon size of opts to 128
        set background picture of opts to file ".background:\(bgName)"
        set position of item "\(appFile)" of container window to {\(Int(dmgAppPos.x)), \(Int(dmgAppPos.y))}
        set position of item "Applications" of container window to {\(Int(dmgAppsPos.x)), \(Int(dmgAppsPos.y))}
        try
          set position of item "\(readme)" of container window to {\(Int(dmgReadmePos.x)), \(Int(dmgReadmePos.y))}
        end try
        update without registering applications
        delay 1
        close
      end tell
    end tell
    """
    let result = shellOutput("/usr/bin/osascript", ["-e", script])
    if result.status != 0 {
        let detail = result.err.trimmingCharacters(in: .whitespacesAndNewlines)
        warn("web-app: could not style the dmg, shipping it plain — \(detail.isEmpty ? "grant your terminal 'control Finder' in Privacy & Security > Automation" : detail)")
    }
}

func cmdDmg(_ args: [String]) {
    guard args.count == 1, isAppFolder(args[0]) else {
        die("web-app: dmg needs one app folder path, e.g. web-app dmg custom/web-apps/opentalk")
    }
    let appSrc = args[0]
    let host = compileHost()
    defer { try? fm.removeItem(atPath: host) }

    let stage = NSTemporaryDirectory() + "web-app-dmg-\(UUID().uuidString)"
    defer { try? fm.removeItem(atPath: stage) }

    guard let appName = buildApp(from: appSrc, hostBin: host, into: "\(stage)/build", register: false) else {
        die("web-app: build produced no .app")
    }
    let name = String(appName.dropLast(".app".count))

    // empty read-write dmg → mount → populate → style → rename → detach → compress.
    // KEY: Finder caches its window state per volume NAME and won't rewrite .DS_Store
    // for a name it has seen, so we style under a throwaway unique name, then rename
    // the volume to the app name (the .DS_Store, with a volume-relative background,
    // survives the rename). the 300m slack is squeezed out by the UDZO conversion.
    let rw = "\(stage)/rw.dmg"
    let stylingVol = "webapp-\(UUID().uuidString.prefix(8))"
    guard shell("/usr/bin/hdiutil", ["create", "-size", "300m", "-fs", "HFS+", "-volname", stylingVol, "-ov", rw]) == 0 else {
        die("web-app: could not create the dmg")
    }
    let attach = shellOutput("/usr/bin/hdiutil", ["attach", rw, "-noverify", "-noautoopen"])
    let device = attach.out.split(whereSeparator: \.isWhitespace).first { $0.hasPrefix("/dev/") }.map(String.init)
    let mnt = attach.out.split(separator: "\n").compactMap { line -> String? in
        line.range(of: "/Volumes/").map { String(line[$0.lowerBound...]).trimmingCharacters(in: .whitespaces) }
    }.last
    guard attach.status == 0, let mnt, let device else { die("web-app: could not mount the dmg") }

    try? fm.copyItem(atPath: "\(stage)/build/\(appName)", toPath: "\(mnt)/\(appName)")
    try? fm.createSymbolicLink(atPath: "\(mnt)/Applications", withDestinationPath: "/Applications")

    let bgName = "background.png"
    let iconPath = load("\(appSrc)/manifest.json")?.icon.flatMap { resolveIcon($0, appDir: appSrc) } ?? ""
    try? fm.createDirectory(atPath: "\(mnt)/.background", withIntermediateDirectories: true)
    _ = renderDMGBackground(iconPath: iconPath, to: "\(mnt)/.background/\(bgName)")

    // first-launch read-me (the app is ad-hoc signed, so gatekeeper blocks it once)
    let readme = "Read me first.txt"
    let steps = """
    Installing \(name)
    ================

    1. Drag \(name) onto the Applications shortcut.
    2. First launch: right-click (Control-click) \(name) in Applications → Open →
       confirm. (A plain double-click is blocked because the app is ad-hoc signed,
       not notarised.) After that it opens normally.

    Or once in Terminal:  xattr -dr com.apple.quarantine "/Applications/\(name).app"
    """
    try? steps.write(toFile: "\(mnt)/\(readme)", atomically: true, encoding: .utf8)

    styleDMG(volume: stylingVol, appFile: appName, bgName: bgName, readme: readme)

    shell("/bin/sleep", ["2"])                                // let Finder flush .DS_Store
    shell("/usr/sbin/diskutil", ["rename", mnt, name])        // throwaway name -> app name
    shell("/bin/sync", [])
    shell("/usr/bin/hdiutil", ["detach", device, "-force"])   // by device: the mount path changed

    let dist = root.appendingPathComponent("dist").path
    try? fm.createDirectory(atPath: dist, withIntermediateDirectories: true)
    let out = "\(dist)/\(name).dmg"
    try? fm.removeItem(atPath: out)
    guard shell("/usr/bin/hdiutil", ["convert", rw, "-format", "UDZO", "-o", out]) == 0 else {
        die("web-app: dmg convert failed")
    }
    print("made \(out)")
}

// MARK: dispatch

let cmd = argv.count > 1 ? argv[1] : "build"
let rest = Array(argv.dropFirst(2))
switch cmd {
case "build": cmdBuild(rest)
case "dmg": cmdDmg(rest)
case "-h", "--help", "help":
    print("""
    web-app <command>
      build [<path>...] [--out DIR]  build apps; default out = /Applications (install).
                                     no path = the host's managed set (allowlist+prune)
      dmg <path>                     package one app folder as dist/<Name>.dmg
    """)
default: die("web-app: unknown command '\(cmd)' (build | dmg)")
}

#else
print("web-app: macOS only, skipping.")
#endif
