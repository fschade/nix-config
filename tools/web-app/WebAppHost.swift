import Cocoa
import UserNotifications
import WebKit

// Generic web-app host. One compiled binary serves every generated .app bundle:
// the target URL, title and per-app links come from the bundle's Info.plist,
// stamped in by tools/web-app/web-app.swift from custom/web-apps/<slug>/manifest.json.
// A website becomes a real, standalone Mac app with its own icon, window and
// process — a native toolbar/menu to navigate, native macOS notifications
// (WKWebView has none of its own), a persistent session, "open in browser"
// and a real logout.
//
// AppDelegate is split across files by concern, each an extension:
//   WebAppHost.swift   this file — launch, window lifecycle, settings, shared state
//   Navigation.swift   back/forward/reload/overview/logout/zoom + the section logic
//   Toolbar.swift      the window toolbar items
//   Menu.swift         the menu bar (app/edit/view/window/go) + about panel
//   Browser.swift      WKWebView delegates: policy, downloads, auth, errors, progress
//   Notifications.swift the web-notification bridge + our own page messages
//   FindBar.swift      the ⌘F find-on-page strip

// injected before the page runs: replace window.Notification so the page's
// desktop notifications get bridged to real macOS notifications via the handler.
private let notificationShim = """
(function () {
  var post = function (m) {
    try { window.webkit.messageHandlers.notify.postMessage(m); } catch (e) {}
  };
  function N(title, options) {
    options = options || {};
    post({ title: String(title || ''), body: String(options.body || '') });
    this.onclick = this.onclose = this.onerror = this.onshow = null;
    this.close = function () {};
    this.addEventListener = function () {};
    this.removeEventListener = function () {};
  }
  N.permission = 'granted';
  N.maxActions = 2;
  N.requestPermission = function (cb) {
    post({ requestPermission: true });
    if (typeof cb === 'function') cb('granted');
    return Promise.resolve('granted');
  };
  try {
    Object.defineProperty(window, 'Notification', { value: N, configurable: true, writable: true });
  } catch (e) {
    window.Notification = N;
  }
})();
"""

// The key window gets performKeyEquivalent before the main menu, and WKWebView
// returns true for almost every ⌘-combo — so it swallows our menu shortcuts
// (⌘1…9, ⌘R, ⌘[/⌘] …) before the menu ever sees them. Give the menu the first
// pick, like a browser does; editing keys (⌘C/⌘V/⌘Z) still reach the web view
// because their menu items route through the responder chain back to it.
final class ShortcutWebView: WKWebView {
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if NSApp.mainMenu?.performKeyEquivalent(with: event) == true { return true }
        return super.performKeyEquivalent(with: event)
    }
}

extension NSToolbarItem.Identifier {
    static let nav = NSToolbarItem.Identifier("nav")
    static let reload = NSToolbarItem.Identifier("reload")
    static let home = NSToolbarItem.Identifier("home")
    static let links = NSToolbarItem.Identifier("links")
    static let openInBrowser = NSToolbarItem.Identifier("openInBrowser")
    static let logout = NSToolbarItem.Identifier("logout")
    static let title = NSToolbarItem.Identifier("title")
    static let downloads = NSToolbarItem.Identifier("downloads")
}

final class AppDelegate: NSObject, NSApplicationDelegate, WKUIDelegate, WKNavigationDelegate,
    WKScriptMessageHandler, UNUserNotificationCenterDelegate, NSToolbarDelegate,
    NSWindowDelegate, WKDownloadDelegate, NSSearchFieldDelegate {
    // shared state. AppDelegate lives across several files, so these are internal
    // (Swift `private` is file-scoped and the extensions couldn't see them).
    var window: NSWindow!
    var webView: WKWebView!
    var title = "Web App"
    var homeURL: URL?
    var menuItems: [(title: String, url: URL, section: String?)] = [] // per-app jump targets, optional group
    var titleField: NSTextField? // centered titlebar label; tooltip = current url
    var settings: SettingsController?
    var bakedURL = "about:blank"          // config defaults, for Settings' reset
    var bakedLinks: [[String: String]] = []
    var bakedAllowSelfSigned = false
    var bakedKeepRunning = false
    var bakedExternalLinks = false
    var allowSelfSigned = false           // accept self-signed tls (opt-in)
    var keepRunning = false               // closing the window hides it instead of quitting
    var externalLinksInBrowser = false    // off-domain links open in the default browser
    var bakedUserAgent: String?           // optional custom UA baked from the manifest
    var bakedInspectable = false          // manifest opt-in: enable the Web Inspector
    var windowWidth: CGFloat = 1100       // initial window size (manifest override)
    var windowHeight: CGFloat = 800
    let findBar = NSVisualEffectView() // translucent find strip
    let findField = NSSearchField()
    let progressBar = NSView() // thin accent-coloured load progress under the toolbar
    var progressObs: NSKeyValueObservation? // KVO on estimatedProgress
    var downloadItems: [DownloadItem] = [] // all downloads this session (safari-style list)
    var downloadObs: [ObjectIdentifier: NSKeyValueObservation] = [:] // KVO per download
    weak var downloadsButton: DownloadsButton? // toolbar button with a progress ring
    var downloadsPopover: NSPopover? // the downloads list
    var titleObs: NSKeyValueObservation?    // KVO on the page <title> (live titlebar)
    var urlObs: NSKeyValueObservation?      // KVO on the url (SPA route changes)
    var lastFailedURL: URL? // for the error page's Retry button
    // UNUserNotificationCenter asserts if the process isn't a real .app bundle
    // (e.g. run bare from Xcode), so gate notifications on having a bundle id.
    let hasBundle = Bundle.main.bundleIdentifier != nil

    func applicationDidFinishLaunching(_ note: Notification) {
        // read the baked config out of Info.plist
        let info = Bundle.main.infoDictionary ?? [:]
        title = info["CFBundleName"] as? String ?? title
        // production always bakes WebAppURL; the fallback only hits when run without
        // a built bundle (e.g. from Xcode), so show a real page rather than blank.
        bakedURL = info["WebAppURL"] as? String ?? "https://example.com/"
        bakedLinks = info["WebAppMenu"] as? [[String: String]] ?? []
        bakedAllowSelfSigned = info["WebAppAllowSelfSignedCerts"] as? Bool ?? false
        bakedKeepRunning = info["WebAppKeepRunning"] as? Bool ?? false
        bakedExternalLinks = info["WebAppExternalLinksInBrowser"] as? Bool ?? false
        bakedUserAgent = info["WebAppUserAgent"] as? String
        bakedInspectable = info["WebAppInspectable"] as? Bool ?? false
        windowWidth = (info["WebAppWindowWidth"] as? Double).map { CGFloat($0) } ?? 1100
        windowHeight = (info["WebAppWindowHeight"] as? Double).map { CGFloat($0) } ?? 800

        // register the config values as defaults; Settings edits override them
        UserDefaults.standard.register(defaults: [
            kWebAppHomeURL: bakedURL,
            kWebAppLinks: bakedLinks,
            kWebAppAllowSelfSigned: bakedAllowSelfSigned,
            kWebAppKeepRunning: bakedKeepRunning,
            kWebAppExternalLinks: bakedExternalLinks,
        ])
        loadFromDefaults()

        if hasBundle {
            let center = UNUserNotificationCenter.current()
            center.delegate = self
            center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        }

        let content = WKUserContentController()
        content.add(self, name: "notify")
        content.add(self, name: "webapp") // in-app actions (e.g. the error page's Retry)
        content.addUserScript(WKUserScript(source: notificationShim,
                                           injectionTime: .atDocumentStart,
                                           forMainFrameOnly: false))

        let config = WKWebViewConfiguration()
        config.userContentController = content
        config.mediaTypesRequiringUserActionForPlayback = []
        config.websiteDataStore = .default() // persistent: keeps logins across launches
        // WKWebView's default UA drops the "Version/x Safari/605.1.15" token real
        // Safari sends, so sites that sniff for Safari flag it as unsupported even
        // though it's the same engine. present as full desktop Safari by default,
        // unless the manifest pins a custom userAgent (e.g. to look like Chrome).
        if bakedUserAgent?.isEmpty ?? true {
            config.applicationNameForUserAgent = safariUAToken()
        }

        webView = ShortcutWebView(frame: .zero, configuration: config)
        webView.uiDelegate = self
        webView.navigationDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.allowsMagnification = true // ⌘+/- zoom
        if let ua = bakedUserAgent, !ua.isEmpty { webView.customUserAgent = ua }
        // hidden dev aid: manifest "inspectable" enables the Web Inspector, then
        // right-click the page -> "Inspect Element" opens the console/devtools.
        if #available(macOS 13.3, *), bakedInspectable { webView.isInspectable = true }

        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered, defer: false)
        window.title = title
        window.center()
        window.setFrameAutosaveName("WebAppMainWindow")
        window.delegate = self

        // container holds the web view plus the (hidden) find bar overlaid on top
        let container = NSView(frame: NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight))
        webView.frame = container.bounds
        webView.autoresizingMask = [.width, .height]
        container.addSubview(webView)
        setupFindBar(in: container)
        setupProgressBar(in: container)
        window.contentView = container

        // drive the load progress bar off the web view's own estimate
        progressObs = webView.observe(\.estimatedProgress, options: [.new]) { [weak self] wv, _ in
            self?.updateProgress(wv.estimatedProgress)
        }
        // keep the "app — section — page" titlebar live through SPA navigation
        titleObs = webView.observe(\.title, options: [.new]) { [weak self] _, _ in self?.updateTitle() }
        urlObs = webView.observe(\.url, options: [.new]) { [weak self] _, _ in self?.updateTitle() }

        installToolbar()
        buildMenu()

        if let url = homeURL {
            webView.load(URLRequest(url: url))
        }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: window lifecycle

    func applicationShouldTerminateAfterLastWindowClosed(_ app: NSApplication) -> Bool { !keepRunning }

    // keepRunning apps (e.g. pushover, for notifications) hide on close instead of
    // quitting; a dock click brings the window back, ⌘Q still quits.
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard keepRunning else { return true }
        window.orderOut(nil)
        return false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { showMainWindow() }
        return true
    }

    // reopen only fires on a dock click; ⌘-Tab activates the app without it, so a
    // keepRunning app whose window was closed (hidden) would come forward with no
    // window and no way back. Re-show it whenever the app becomes active.
    func applicationDidBecomeActive(_ note: Notification) {
        if keepRunning, let window, !window.isVisible { window.makeKeyAndOrderFront(nil) }
    }

    // bring the (possibly hidden) main window back; also the "Window > Show" action
    @objc func showMainWindow() {
        window.makeKeyAndOrderFront(nil)
    }

    // MARK: settings (UserDefaults-backed; the manifest is only the seed)

    private func loadFromDefaults() {
        let d = UserDefaults.standard
        homeURL = URL(string: d.string(forKey: kWebAppHomeURL) ?? bakedURL)
        let raw = d.array(forKey: kWebAppLinks) as? [[String: String]] ?? bakedLinks
        menuItems = raw.compactMap { entry in
            guard let label = entry["title"], let link = entry["url"], let url = URL(string: link) else { return nil }
            let section = entry["section"].flatMap { $0.isEmpty ? nil : $0 }
            return (label, url, section)
        }
        allowSelfSigned = d.bool(forKey: kWebAppAllowSelfSigned)
        keepRunning = d.bool(forKey: kWebAppKeepRunning)
        externalLinksInBrowser = d.bool(forKey: kWebAppExternalLinks)
    }

    @objc func openSettings() {
        if settings == nil {
            settings = SettingsController(defaultLinks: bakedLinks, defaultHomeURL: bakedURL,
                                          defaultAllowSelfSigned: bakedAllowSelfSigned,
                                          defaultKeepRunning: bakedKeepRunning,
                                          defaultExternalLinks: bakedExternalLinks) { [weak self] in
                self?.settingsChanged()
            }
        }
        settings?.showWindow(nil)
        settings?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func settingsChanged() {
        loadFromDefaults()
        installToolbar() // the links dropdown may now appear or disappear
        buildMenu()
        updateTitle() // section mapping may have changed
    }

    // MARK: shared UI helpers

    func symbol(_ name: String, _ desc: String) -> NSImage {
        NSImage(systemSymbolName: name, accessibilityDescription: desc) ?? NSImage()
    }

    // real Safari's marketing version drives the UA "Version/" token; the build
    // token stays 605.1.15 (what WKWebView already emits). read it off the installed
    // Safari so we never invent a number; fall back to just the build token.
    private func safariUAToken() -> String {
        if let plist = NSDictionary(contentsOfFile: "/Applications/Safari.app/Contents/Info.plist"),
           let v = plist["CFBundleShortVersionString"] as? String, !v.isEmpty {
            return "Version/\(v) Safari/605.1.15"
        }
        return "Safari/605.1.15"
    }

    func button(_ id: NSToolbarItem.Identifier, _ label: String,
                _ symbolName: String, _ action: Selector) -> NSToolbarItem {
        let item = NSToolbarItem(itemIdentifier: id)
        item.label = label
        item.toolTip = label
        item.image = symbol(symbolName, label)
        item.target = self
        item.action = action
        item.isBordered = true
        return item
    }
}

@main
enum WebApp {
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        let delegate = AppDelegate()
        app.delegate = delegate // NSApplication.delegate is weak; the local keeps it alive during run()
        app.run()
    }
}
