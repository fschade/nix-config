#!/usr/bin/env swift
#if os(macOS)
import AppKit
import CryptoKit

// the web-app builder: compiles the shared WKWebView host, then stamps .app
// bundles from app folders in custom/web-apps/<slug>/.
//
//   web-app.swift build [<path>...] [--out <dir>]   default --out /Applications
//   web-app.swift dmg <path>                        package as dist/<Name>.dmg

let fm = FileManager.default
let env = ProcessInfo.processInfo.environment
let argv = CommandLine.arguments

func warn(_ s: String) { FileHandle.standardError.write((s + "\n").data(using: .utf8)!) }
func die(_ s: String) -> Never { warn(s); exit(2) }

let scriptDir = URL(fileURLWithPath: argv[0]).deletingLastPathComponent()
let root = env["MISE_PROJECT_ROOT"].map { URL(fileURLWithPath: $0) }
    ?? scriptDir.deletingLastPathComponent().deletingLastPathComponent()
let webappsDir = root.appendingPathComponent("custom/web-apps").path
let hereDir = scriptDir.path // where the host sources live
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
    var icon: String?           // required; relative to the app folder, or an https url
    var iconBackground: String? // optional #rrggbb; else white (source art fills the tile)
    var links: [Link]?
    var allowSelfSignedCerts: Bool? // opt-in: accept self-signed/invalid tls for this app
    var keepRunningWhenClosed: Bool? // closing the window hides it, app keeps running (e.g. pushover)
    var openExternalLinksInBrowser: Bool? // off-domain link clicks open in the default browser
    var version: String?     // -> CFBundleShortVersionString (default "1.0")
    var author: String?      // -> NSHumanReadableCopyright, shown in About
    var description: String? // -> a blurb in the About panel
    var homepage: String?    // -> a clickable link in the About panel
    var bundleId: String?    // -> CFBundleIdentifier (default com.fschade.webapp.<slug>)
    var userAgent: String?   // -> WKWebView.customUserAgent (e.g. to look like Chrome)
    var inspectable: Bool?   // -> WKWebView.isInspectable (attach from Safari > Develop)
    var window: WindowSize?  // -> initial window size (default 1100x800)
    var toolbar: [ToolbarEntry]? // -> toolbar layout: names, "|" split, nested arrays as groups
    var inject: Inject?          // -> per-app js/css injected into the page
    var buttons: [ButtonConfig]? // -> custom toolbar buttons running js in the page
}

struct Inject: Codable {
    var css: [InjectEntry]?
    var js: [InjectEntry]?
}

struct InjectEntry: Codable {
    let file: String
    let urlContains: String?

    private enum CodingKeys: String, CodingKey { case file, urlContains }

    init(from decoder: Decoder) throws {
        if let c = try? decoder.singleValueContainer(), let s = try? c.decode(String.self) {
            file = s
            urlContains = nil
            return
        }
        let c = try decoder.container(keyedBy: CodingKeys.self)
        file = try c.decode(String.self, forKey: .file)
        urlContains = try c.decodeIfPresent(String.self, forKey: .urlContains)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(file, forKey: .file)
        try c.encodeIfPresent(urlContains, forKey: .urlContains)
    }
}

// symbolOn makes it a toggle, the js return value is the state. key is the menu
// shortcut (lowercase = cmd, uppercase = cmd+shift).
struct ButtonConfig: Codable {
    var name: String?
    var label: String?
    var symbol: String?
    var symbolOn: String?
    var js: String?
    var jsFile: String?
    var key: String?
}

enum ToolbarEntry: Codable {
    case button(String)
    case group([String])

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let name = try? c.decode(String.self) {
            self = .button(name)
        } else {
            self = .group(try c.decode([String].self))
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .button(let name): try c.encode(name)
        case .group(let names): try c.encode(names)
        }
    }
}

// mirrors the hosts toolbarButtonLabels (Settings.swift), the builder is separate
let knownToolbarButtons: Set<String> = [
    "home", "links", "nav", "reload", "muteAudio", "muteMic", "openInBrowser", "logout",
]

struct WindowSize: Codable {
    var width: Double?
    var height: Double?
}

// string-aware, so the // in a url survives
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

// memoized by path, one run never sees a file change
var loadCache: [String: AppConfig?] = [:]
func load(_ path: String) -> AppConfig? {
    if let cached = loadCache[path] { return cached }
    let result = loadUncached(path)
    loadCache[path] = result
    return result
}

func loadUncached(_ path: String) -> AppConfig? {
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

// sRGB so the background matches the artwork exactly, device-rgb leaves a ring
let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!

// set iconBackground when the artwork has transparent corners
func background(_ hex: String?) -> CGColor {
    let white = CGColor(colorSpace: sRGB, components: [1, 1, 1, 1])!
    guard var s = hex else { return white }
    if s.hasPrefix("#") { s.removeFirst() }
    guard s.count == 6, let value = Int(s, radix: 16) else { return white }
    let red = Double((value >> 16) & 0xff), green = Double((value >> 8) & 0xff), blue = Double(value & 0xff)
    return CGColor(colorSpace: sRGB, components: [red / 255, green / 255, blue / 255, 1]) ?? white
}

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

func buildIcon(source: String, background bg: CGColor, into bundle: String, slug: String) -> Bool {
    let base = NSTemporaryDirectory() + "webapp-\(slug)-\(UUID().uuidString)"
    let iconset = base + ".iconset"
    let master = base + ".png"
    try? fm.createDirectory(atPath: iconset, withIntermediateDirectories: true)
    defer { try? fm.removeItem(atPath: iconset); try? fm.removeItem(atPath: master) }
    guard renderIcon(source: source, background: bg, to: master) else {
        warn("web-app: could not render icon from \(source)")
        return false
    }
    for s in [16, 32, 128, 256, 512] {
        for side in [s, s * 2] {
            let suffix = side == s ? "" : "@2x"
            guard shell("/usr/bin/sips", ["-z", "\(side)", "\(side)", master,
                                          "--out", "\(iconset)/icon_\(s)x\(s)\(suffix).png"]) == 0 else {
                warn("web-app: sips failed on the \(side)px icon")
                return false
            }
        }
    }
    let status = shell("/usr/bin/iconutil", ["-c", "icns", iconset, "-o", "\(bundle)/Contents/Resources/icon.icns"])
    if status != 0 { warn("web-app: iconutil failed (exit \(status))") }
    return status == 0
}

// MARK: host + bundle building

// cached under a content hash, an unchanged source set skips the ~11s swiftc run
func compileHost() -> String {
// a new .swift here that is NOT host code must also go in Package.swifts `exclude`
    let notHost: Set<String> = ["web-app.swift", "Package.swift"]
    let sources = ((try? fm.contentsOfDirectory(atPath: hereDir)) ?? [])
        .filter { $0.hasSuffix(".swift") && !notHost.contains($0) }
        .sorted()
        .map { "\(hereDir)/\($0)" }
    guard !sources.isEmpty else { die("web-app: no host sources in \(hereDir)") }

    let optFlags = ["-O"]
    let frameworks = ["-framework", "Cocoa", "-framework", "WebKit", "-framework", "UserNotifications"]

    var hasher = SHA256()
    for path in sources {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
            die("web-app: cannot read host source \(path)")
        }
        hasher.update(data: data)
    }
    hasher.update(data: Data((optFlags + frameworks).joined(separator: " ").utf8))
    hasher.update(data: Data(shellOutput("/usr/bin/swiftc", ["--version"]).out.utf8))
    let key = hasher.finalize().map { String(format: "%02x", $0) }.joined()

    let cacheDir = (fm.urls(for: .cachesDirectory, in: .userDomainMask).first?.path
        ?? NSTemporaryDirectory()) + "/web-app-host"
    let cached = "\(cacheDir)/\(key)"
    if fm.isExecutableFile(atPath: cached) {
        print("web-app host: cache hit, skipping compile")
        return cached
    }

    print("compiling web-app host...")
    let tmp = NSTemporaryDirectory() + "WebAppHost-\(UUID().uuidString)"
    let status = shell("/usr/bin/swiftc", optFlags + sources + ["-o", tmp] + frameworks, quiet: false)
    guard status == 0 else { die("web-app: host compile failed (swiftc exit \(status))") }
    try? fm.createDirectory(atPath: cacheDir, withIntermediateDirectories: true)
    if fm.fileExists(atPath: cached) { try? fm.removeItem(atPath: cached) }
    guard (try? fm.moveItem(atPath: tmp, toPath: cached)) != nil else { return tmp }
    return cached
}

// https only: the artwork ends up in a signed bundle, plain http is tamperable
func resolveIcon(_ ref: String, appDir: String) -> String? {
    if ref.hasPrefix("http://") {
        warn("web-app: refusing insecure icon url \(ref), use https or a local file")
        return nil
    }
    if ref.hasPrefix("https://") {
        guard let url = URL(string: ref) else {
            warn("web-app: could not download icon \(ref)")
            return nil
        }
// only a 200 counts, a 404 body would land as the artwork
        var payload: Data?
        var problem = "no response"
        let done = DispatchSemaphore(value: 0)
        URLSession.shared.dataTask(with: url) { data, response, error in
            defer { done.signal() }
            if let error { problem = error.localizedDescription; return }
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard code == 200 else { problem = "http \(code)"; return }
            payload = data
        }.resume()
        done.wait()
        guard let data = payload else {
            warn("web-app: could not download icon \(ref): \(problem)")
            return nil
        }
        let ext = url.pathExtension // of the parsed url, so a ?query doesn't leak in
        let tmp = NSTemporaryDirectory() + "webapp-icon-\(UUID().uuidString)" + (ext.isEmpty ? "" : ".\(ext)")
        return (try? data.write(to: URL(fileURLWithPath: tmp))) != nil ? tmp : nil
    }
    let path = "\(appDir)/\(ref)"
    return fm.fileExists(atPath: path) ? path : nil
}

func buildApp(from appDir: String, hostBin: String, into outDir: String, register: Bool) -> String? {
    let manifest = "\(appDir)/manifest.jsonc"
    guard fm.fileExists(atPath: manifest) else {
        warn("web-app: no manifest.jsonc in \(appDir), skipping")
        return nil
    }
// load() already printed the parse error, dont mask it
    guard var cfg = load(manifest) else {
        warn("web-app: \(manifest) could not be read or parsed, skipping")
        return nil
    }
    if let ov = load("\(appDir)/manifest.local.jsonc") {
        if let v = ov.name { cfg.name = v }
        if let v = ov.url { cfg.url = v }
        if let v = ov.icon { cfg.icon = v }
        if let v = ov.iconBackground { cfg.iconBackground = v }
        if let v = ov.links { cfg.links = (cfg.links ?? []) + v }
        if let v = ov.allowSelfSignedCerts { cfg.allowSelfSignedCerts = v }
        if let v = ov.keepRunningWhenClosed { cfg.keepRunningWhenClosed = v }
        if let v = ov.openExternalLinksInBrowser { cfg.openExternalLinksInBrowser = v }
        if let v = ov.version { cfg.version = v }
        if let v = ov.author { cfg.author = v }
        if let v = ov.description { cfg.description = v }
        if let v = ov.homepage { cfg.homepage = v }
        if let v = ov.bundleId { cfg.bundleId = v }
        if let v = ov.userAgent { cfg.userAgent = v }
        if let v = ov.inspectable { cfg.inspectable = v }
        if let v = ov.window { cfg.window = v }
        if let v = ov.toolbar { cfg.toolbar = v }
        if let v = ov.inject {
            cfg.inject = Inject(css: (cfg.inject?.css ?? []) + (v.css ?? []),
                                js: (cfg.inject?.js ?? []) + (v.js ?? []))
        }
        if let v = ov.buttons { cfg.buttons = (cfg.buttons ?? []) + v }
    }
    guard let name = cfg.name, let url = cfg.url, let iconRef = cfg.icon else {
        warn("web-app: \(manifest) needs name, url and icon, skipping")
        return nil
    }
    guard name.rangeOfCharacter(from: CharacterSet(charactersIn: "/:\"\\")) == nil else {
        warn("web-app: \(manifest): name must not contain / : \" \\, skipping")
        return nil
    }
    guard let iconPath = resolveIcon(iconRef, appDir: appDir) else {
        warn("web-app: \(name): icon \(iconRef) not available, skipping")
        return nil
    }

    let slug = slugify(name)
    guard !slug.isEmpty else {
        warn("web-app: \(manifest): name needs at least one ascii letter or digit, skipping")
        return nil
    }
    let bundle = "\(outDir)/\(name).app"
    print("building \(name) -> \(bundle)")

    // swap in only once signed, so the installed app survives a build that dies
    let stage = "\(outDir)/.web-app-staging-\(UUID().uuidString.prefix(8))"
    let staged = "\(stage)/\(name).app"
    defer { try? fm.removeItem(atPath: stage) }
    do {
        try fm.createDirectory(atPath: "\(staged)/Contents/MacOS", withIntermediateDirectories: true)
        try fm.createDirectory(atPath: "\(staged)/Contents/Resources", withIntermediateDirectories: true)
        try fm.copyItem(atPath: hostBin, toPath: "\(staged)/Contents/MacOS/WebAppHost")
        try fm.copyItem(atPath: "\(hereDir)/assets", toPath: "\(staged)/Contents/Resources/assets")
    } catch {
        warn("web-app: \(name): \(error)")
        return nil
    }

    guard buildIcon(source: iconPath, background: background(cfg.iconBackground), into: staged, slug: slug) else {
        warn("web-app: \(name): no icon, skipping")
        return nil
    }

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
    if let v = cfg.author, !v.isEmpty { info["NSHumanReadableCopyright"] = v }
    if let v = cfg.description, !v.isEmpty { info["WebAppDescription"] = v }
    if let v = cfg.homepage, !v.isEmpty { info["WebAppHomepage"] = v }
    if let v = cfg.userAgent, !v.isEmpty { info["WebAppUserAgent"] = v }
    if cfg.inspectable == true { info["WebAppInspectable"] = true }
    if let w = cfg.window?.width { info["WebAppWindowWidth"] = w }
    if let h = cfg.window?.height { info["WebAppWindowHeight"] = h }

    // baked in, so the bundle stays self-contained
    func bakeInject(_ entries: [InjectEntry]?, kind: String) -> [[String: String]] {
        (entries ?? []).compactMap { entry in
            guard let code = try? String(contentsOfFile: "\(appDir)/\(entry.file)", encoding: .utf8) else {
                warn("web-app: \(name): \(kind) file \(entry.file) not readable, skipping it")
                return nil
            }
            var baked = ["code": code]
            if let filter = entry.urlContains, !filter.isEmpty { baked["urlContains"] = filter }
            return baked
        }
    }
    let injectCSS = bakeInject(cfg.inject?.css, kind: "css")
    if !injectCSS.isEmpty { info["WebAppInjectCSS"] = injectCSS }
    let injectJS = bakeInject(cfg.inject?.js, kind: "js")
    if !injectJS.isEmpty { info["WebAppInjectJS"] = injectJS }

    var customNames: [String] = []
    if let buttons = cfg.buttons {
        var baked: [[String: String]] = []
        for b in buttons {
            guard let bName = b.name, !bName.isEmpty, let label = b.label, !label.isEmpty else {
                warn("web-app: \(name): a custom button needs name and label, skipping it")
                continue
            }
            guard !knownToolbarButtons.contains(bName), bName != "|", !customNames.contains(bName) else {
                warn("web-app: \(name): button name \(bName) collides with an existing one, skipping it")
                continue
            }
            var js = b.js
            if js == nil, let f = b.jsFile {
                js = try? String(contentsOfFile: "\(appDir)/\(f)", encoding: .utf8)
                guard js != nil else {
                    warn("web-app: \(name): button \(bName): jsFile \(f) not readable, skipping the button")
                    continue
                }
            }
            var d = ["name": bName, "label": label]
            if let js, !js.isEmpty { d["js"] = js }
            if let v = b.symbol, !v.isEmpty { d["symbol"] = v }
            if let v = b.symbolOn, !v.isEmpty { d["symbolOn"] = v }
            if let v = b.key {
                // NSMenuItem keyEquivalent is one character
                if v.count == 1 { d["key"] = v } else if !v.isEmpty {
                    warn("web-app: \(name): button \(bName): key must be a single character, dropping it")
                }
            }
            baked.append(d)
            customNames.append(bName)
        }
        if !baked.isEmpty { info["WebAppButtons"] = baked }
    }

    if let layout = cfg.toolbar {
        let known = knownToolbarButtons.union(customNames)
        var baked: [Any] = []
        var unknown: [String] = []
        var splits = 0
        for entry in layout {
            switch entry {
            case .button("|"):
                splits += 1
                if splits == 1 { baked.append("|") }
            case .button(let n):
                if known.contains(n) { baked.append(n) } else { unknown.append(n) }
            case .group(let names):
                unknown += names.filter { !known.contains($0) }
                let good = names.filter { known.contains($0) }
                if !good.isEmpty { baked.append(good) }
            }
        }
        if !unknown.isEmpty {
            warn("web-app: \(name): unknown toolbar entries \(unknown.joined(separator: ", ")), ignoring them")
        }
        if splits > 1 { warn("web-app: \(name): more than one \"|\" in toolbar, keeping the first") }
        info["WebAppToolbar"] = baked
    }
    if let links = cfg.links, !links.isEmpty {
        info["WebAppMenu"] = links.map { link -> [String: String] in
            var m = ["title": link.title, "url": link.url]
            if let s = link.section, !s.isEmpty { m["section"] = s }
            return m
        }
    }
    guard let plist = try? PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0) else {
        warn("web-app: \(name): could not serialize Info.plist")
        return nil
    }
    guard fm.createFile(atPath: "\(staged)/Contents/Info.plist", contents: plist),
          fm.createFile(atPath: "\(staged)/Contents/Resources/\(marker)", contents: nil) else {
        warn("web-app: \(name): could not write Info.plist and marker into \(staged)")
        return nil
    }

    // gatekeeper refuses an unsigned bundle, so a failed sign is a failed build
    let signed = shellOutput("/usr/bin/codesign", ["--force", "--deep", "--sign", "-", staged])
    guard signed.status == 0 else {
        let detail = signed.err.trimmingCharacters(in: .whitespacesAndNewlines)
        warn("web-app: \(name): codesign failed (exit \(signed.status)), dropping the bundle: \(detail)")
        return nil
    }

    do {
        if fm.fileExists(atPath: bundle) { try fm.removeItem(atPath: bundle) }
        try fm.moveItem(atPath: staged, toPath: bundle)
    } catch {
        warn("web-app: \(name): could not install the bundle: \(error)")
        return nil
    }
    if register {
        let status = shell(lsregister, ["-f", bundle])
        if status != 0 { warn("web-app: \(name): lsregister failed (exit \(status)), open/dock may still show the old bundle") }
    }
    return "\(name).app"
}

func managedFolders() -> [String] {
    // fatal: an empty list would let prune wipe every installed app
    guard let entries = try? fm.contentsOfDirectory(atPath: webappsDir) else {
        die("web-app: no app root at \(webappsDir)")
    }
    return entries.sorted().filter { folder in
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: "\(webappsDir)/\(folder)", isDirectory: &isDir), isDir.boolValue else { return false }
        for legacy in ["manifest.json", "manifest.local.json"]
            where fm.fileExists(atPath: "\(webappsDir)/\(folder)/\(legacy)") {
            warn("web-app: \(folder)/\(legacy) is ignored, rename it to \(legacy.dropLast("json".count))jsonc")
        }
        return fm.fileExists(atPath: "\(webappsDir)/\(folder)/manifest.jsonc")
    }
}

// one slug per line, empty/absent = build everything
func hostAllowlist() -> Set<String> {
    guard let text = try? String(contentsOfFile: allowlistFile, encoding: .utf8) else { return [] }
    return Set(text.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
        .filter { !$0.isEmpty })
}

// keep is what we want installed, not what we just built
func prune(keep: Set<String>, in dir: String) {
    guard let entries = try? fm.contentsOfDirectory(atPath: dir) else { return }
    for e in entries where e.hasSuffix(".app") {
        let m = "\(dir)/\(e)/Contents/Resources/\(marker)"
        if fm.fileExists(atPath: m), !keep.contains(e) {
            print("removing stale \(e)")
            try? fm.removeItem(atPath: "\(dir)/\(e)")
        }
    }
}

func effectiveName(of folder: String) -> String? {
    let dir = "\(webappsDir)/\(folder)"
    let local = load("\(dir)/manifest.local.jsonc")?.name
    return local ?? load("\(dir)/manifest.jsonc")?.name
}

func matches(folder: String, filters: Set<String>) -> Bool {
    if filters.contains(folder.lowercased()) { return true }
    return filters.contains(slugify(effectiveName(of: folder) ?? folder))
}

func isAppFolder(_ path: String) -> Bool {
    var isDir: ObjCBool = false
    return fm.fileExists(atPath: "\(path)/manifest.jsonc")
        && fm.fileExists(atPath: path, isDirectory: &isDir) && isDir.boolValue
}

// MARK: commands

func cmdBuild(_ args: [String]) {
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
    do { try fm.createDirectory(atPath: outDir, withIntermediateDirectories: true) } catch {
        die("web-app: cannot create output dir \(outDir): \(error)")
    }
    let register = URL(fileURLWithPath: outDir).standardizedFileURL.path == "/Applications"

    let host = compileHost() // cached across runs, dont delete it
    var built = Set<String>()

    if paths.isEmpty {
        let filters = hostAllowlist()
        let folders = managedFolders().filter { filters.isEmpty || matches(folder: $0, filters: filters) }
        var keep = Set<String>() // built now, or failed transiently, never prune those
        // prune goes by absence, so only run it when the wanted set is fully known
        var canPrune = true
        var anyFailed = false // a wanted app that didnt end up built, deploy should notice
        for filter in filters.sorted() where !folders.contains(where: { matches(folder: $0, filters: [filter]) }) {
            warn("web-app: allowlist entry '\(filter)' matches no app folder in \(webappsDir), keeping the installed apps")
            canPrune = false
            anyFailed = true
        }
        for folder in folders {
            if let name = buildApp(from: "\(webappsDir)/\(folder)", hostBin: host, into: outDir, register: register) {
                built.insert(name)
                keep.insert(name)
            } else if let name = effectiveName(of: folder) {
                keep.insert("\(name).app")
                anyFailed = true
            } else {
                warn("web-app: \(folder): build failed and its name is unreadable, keeping the installed apps")
                canPrune = false
                anyFailed = true
            }
        }
        if canPrune { prune(keep: keep, in: outDir) }
        print("done: \(built.sorted().joined(separator: " "))")
        if anyFailed { warn("web-app: some managed apps did not build (see above)"); exit(1) }
        return
    }

    for path in paths {
        guard isAppFolder(path) else {
            warn("web-app: \(path) is not an app folder (no manifest.jsonc), skipping")
            continue
        }
        if let name = buildApp(from: path, hostBin: host, into: outDir, register: register) { built.insert(name) }
    }
    if built.isEmpty { die("web-app: no app folder built from \(paths.joined(separator: ", "))") }
    print("done: \(built.sorted().joined(separator: " "))")
}

// points, finder top-left origin. the background matches the window pixel-for-point.
private let dmgSize = NSSize(width: 640, height: 510)
private let dmgAppPos = NSPoint(x: 170, y: 190)    // the .app icon
private let dmgAppsPos = NSPoint(x: 470, y: 190)   // the Applications shortcut
private let dmgReadmePos = NSPoint(x: 320, y: 350) // the first-launch read-me, below

func renderDMGBackground(iconPath: String, to output: String) -> Bool {
    // explicit bitmap at point size, else a retina screen renders 2x and misaligns
    guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(dmgSize.width),
                                     pixelsHigh: Int(dmgSize.height), bitsPerSample: 8,
                                     samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                     colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
          let ctx = NSGraphicsContext(bitmapImageRep: rep) else { return false }
    // the appkit draw path dont reliably hit a bare bitmap. CG origin is bottom-left.
    let cg = ctx.cgContext

    cg.setFillColor(NSColor.white.cgColor)
    cg.fill(CGRect(origin: .zero, size: dmgSize))

    if let icon = NSImage(contentsOfFile: iconPath),
       let cgImage = icon.cgImage(forProposedRect: nil, context: nil, hints: nil) {
        cg.saveGState()
        cg.setAlpha(0.05)
        let s = dmgSize.width
        cg.draw(cgImage, in: CGRect(x: (dmgSize.width - s) / 2, y: (dmgSize.height - s) / 2, width: s, height: s))
        cg.restoreGState()
    }

    // finders y is top-down, flip it to CGs bottom-up
    let appC = CGPoint(x: dmgAppPos.x, y: dmgSize.height - dmgAppPos.y)
    let appsC = CGPoint(x: dmgAppsPos.x, y: dmgSize.height - dmgAppsPos.y)
    let box: CGFloat = 150

    cg.setLineWidth(2)
    cg.setStrokeColor(NSColor(calibratedWhite: 0.4, alpha: 0.3).cgColor)
    cg.setLineDash(phase: 0, lengths: [6, 5])
    for c in [appC, appsC] {
        cg.addPath(CGPath(roundedRect: CGRect(x: c.x - box / 2, y: c.y - box / 2, width: box, height: box),
                          cornerWidth: 20, cornerHeight: 20, transform: nil))
        cg.strokePath()
    }

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

func shellOutput(_ tool: String, _ a: [String]) -> (status: Int32, out: String, err: String) {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: tool)
    p.arguments = a
    let outPipe = Pipe(), errPipe = Pipe()
    p.standardOutput = outPipe
    p.standardError = errPipe
    do { try p.run() } catch { return (-1, "", "\(error)") }
    // drain both pipes concurrently, one after the other deadlocks
    var out = Data(), err = Data()
    let group = DispatchGroup()
    DispatchQueue.global().async(group: group) { out = outPipe.fileHandleForReading.readDataToEndOfFile() }
    DispatchQueue.global().async(group: group) { err = errPipe.fileHandleForReading.readDataToEndOfFile() }
    group.wait()
    p.waitUntilExit()
    return (p.terminationStatus, String(data: out, encoding: .utf8) ?? "", String(data: err, encoding: .utf8) ?? "")
}

// best-effort: without a "control Finder" grant the dmg ships plain
func styleDMG(volume: String, appFile: String, bgName: String, readme: String) {
    guard let template = try? String(contentsOfFile: "\(hereDir)/assets/dmg-layout.applescript", encoding: .utf8) else {
        warn("web-app: assets/dmg-layout.applescript is missing, the dmg ships plain")
        return
    }
    let script = [
        "__VOLUME__": volume,
        "__RIGHT__": "\(300 + Int(dmgSize.width))",
        "__BOTTOM__": "\(160 + Int(dmgSize.height) + 28)",
        "__BG__": bgName,
        "__APP__": appFile,
        "__APP_X__": "\(Int(dmgAppPos.x))", "__APP_Y__": "\(Int(dmgAppPos.y))",
        "__APPS_X__": "\(Int(dmgAppsPos.x))", "__APPS_Y__": "\(Int(dmgAppsPos.y))",
        "__README__": readme,
        "__README_X__": "\(Int(dmgReadmePos.x))", "__README_Y__": "\(Int(dmgReadmePos.y))",
    ].reduce(template) { $0.replacingOccurrences(of: $1.key, with: $1.value) }
    let result = shellOutput("/usr/bin/osascript", ["-e", script])
    if result.status != 0 {
        let detail = result.err.trimmingCharacters(in: .whitespacesAndNewlines)
        warn("web-app: could not style the dmg, shipping it plain: \(detail.isEmpty ? "grant your terminal 'control Finder' in Privacy & Security > Automation" : detail)")
    }
}

func cmdDmg(_ args: [String]) {
    guard args.count == 1, isAppFolder(args[0]) else {
        die("web-app: dmg needs one app folder path, e.g. web-app dmg custom/web-apps/opentalk")
    }
    let appSrc = args[0]
    let host = compileHost() // cached across runs, dont delete it

    let stage = NSTemporaryDirectory() + "web-app-dmg-\(UUID().uuidString)"
    defer { try? fm.removeItem(atPath: stage) }

    guard let appName = buildApp(from: appSrc, hostBin: host, into: "\(stage)/build", register: false) else {
        die("web-app: build produced no .app")
    }
    let name = String(appName.dropLast(".app".count))

    // finder caches window state per volume NAME, so style under a throwaway name
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
    guard attach.status == 0, let mnt, let device else {
        if let device { shell("/usr/bin/hdiutil", ["detach", device, "-force"]) }
        else if let mnt { shell("/usr/bin/hdiutil", ["detach", mnt, "-force"]) }
        die("web-app: could not mount the dmg")
    }

    func abort(_ message: String) -> Never {
        shell("/usr/bin/hdiutil", ["detach", device, "-force"])
        die(message)
    }

    do {
        try fm.copyItem(atPath: "\(stage)/build/\(appName)", toPath: "\(mnt)/\(appName)")
        try fm.createSymbolicLink(atPath: "\(mnt)/Applications", withDestinationPath: "/Applications")
    } catch {
        abort("web-app: could not populate the dmg: \(error)")
    }

    let bgName = "background.png"
    let iconRef = load("\(appSrc)/manifest.local.jsonc")?.icon ?? load("\(appSrc)/manifest.jsonc")?.icon
    let iconPath = iconRef.flatMap { resolveIcon($0, appDir: appSrc) } ?? ""
    try? fm.createDirectory(atPath: "\(mnt)/.background", withIntermediateDirectories: true)
    if !renderDMGBackground(iconPath: iconPath, to: "\(mnt)/.background/\(bgName)") {
        warn("web-app: could not render the dmg background from \(iconPath.isEmpty ? "no icon" : iconPath), the window stays plain")
    }

    // ad-hoc signed, gatekeeper blocks it once: the "open anyway" steps are in here
    let readme = "Read me first.txt"
    if let steps = (try? String(contentsOfFile: "\(hereDir)/assets/dmg-readme.txt", encoding: .utf8))?
        .replacingOccurrences(of: "__NAME__", with: name) {
        do { try steps.write(toFile: "\(mnt)/\(readme)", atomically: true, encoding: .utf8) } catch {
            warn("web-app: could not write \(readme) into the dmg: \(error)")
        }
    } else {
        warn("web-app: assets/dmg-readme.txt is missing, the dmg ships without it")
    }

    styleDMG(volume: stylingVol, appFile: appName, bgName: bgName, readme: readme)

    shell("/bin/sleep", ["2"]) // let finder flush .DS_Store
    let renamed = shell("/usr/sbin/diskutil", ["rename", mnt, name])
    if renamed != 0 { warn("web-app: could not rename the volume to \(name) (exit \(renamed)), the dmg keeps its build name") }
    shell("/bin/sync", [])
    let detached = shell("/usr/bin/hdiutil", ["detach", device, "-force"])
    if detached != 0 { warn("web-app: could not detach \(device) (exit \(detached)), the volume stays mounted") }

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
