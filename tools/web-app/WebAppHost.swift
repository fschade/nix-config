import Cocoa
import UserNotifications
import WebKit

func assetString(_ name: String) -> String {
    #if SWIFT_PACKAGE
    let bundle = Bundle.module
    #else
    let bundle = Bundle.main
    #endif
    guard let url = bundle.url(forResource: name, withExtension: nil, subdirectory: "assets"),
          let text = try? String(contentsOf: url, encoding: .utf8) else {
        NSLog("web-app: missing asset %@", name)
        return ""
    }
    return text
}

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
    static let muteAudio = NSToolbarItem.Identifier("muteAudio")
    static let muteMic = NSToolbarItem.Identifier("muteMic")
    static let openInBrowser = NSToolbarItem.Identifier("openInBrowser")
    static let logout = NSToolbarItem.Identifier("logout")
    static let title = NSToolbarItem.Identifier("title")
    static let downloads = NSToolbarItem.Identifier("downloads")
}

final class AppDelegate: NSObject, NSApplicationDelegate, WKUIDelegate, WKNavigationDelegate,
    WKScriptMessageHandler, UNUserNotificationCenterDelegate, NSToolbarDelegate,
    NSWindowDelegate, WKDownloadDelegate, NSSearchFieldDelegate {
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
    var bakedToolbarLayout = defaultToolbarLayout
    var allowSelfSigned = false           // accept self-signed tls (opt-in)
    var keepRunning = false               // closing the window hides it instead of quitting
    var externalLinksInBrowser = false    // off-domain links open in the default browser
    var toolbarButtons = Set(toolbarLayoutNames(defaultToolbarLayout)) // which layout buttons show
    var audioMuted = false                // page sound muted via the injected shim (Audio.swift)
    var micMutePending = false            // mic mute armed before the page captures (enter a room muted)
    var micObs: NSKeyValueObservation?    // KVO on microphoneCaptureState (page starts/stops capture)
    var customButtons: [CustomButton] = [] // manifest-defined buttons running js (Inject.swift)
    var customStates: [String: Bool] = [:] // toggle state per custom button, reset on page load
    var injectedCSS: [(code: String, filter: String?)] = []
    var bakedUserAgent: String?
    var bakedInspectable = false          // manifest seed for the Settings toggle
    var inspectable = false               // page inspectable from safari > develop, no context menu item
    var windowWidth: CGFloat = 1100       // initial window size (manifest override)
    var windowHeight: CGFloat = 800
    let findBar = NSVisualEffectView() // translucent find strip
    let findField = NSSearchField()
    let progressBar = NSView() // thin accent-coloured load progress under the toolbar
    var progressObs: NSKeyValueObservation? // KVO on estimatedProgress
    var downloadItems: [DownloadItem] = [] // all downloads this session
    var downloadObs: [ObjectIdentifier: NSKeyValueObservation] = [:] // KVO per download
    weak var downloadsButton: DownloadsButton?
    var downloadsPopover: NSPopover?
    var popups: [PopupWindow] = []          // open window.open windows (Popup.swift)
    var titleObs: NSKeyValueObservation?    // KVO on the page <title> (live titlebar)
    var urlObs: NSKeyValueObservation?      // KVO on the url (SPA route changes)
    var lastFailedURL: URL? // for the error page's Retry button
    var contentTerminations = 0 // consecutive web content process kills, reset on a finished load
    let hasBundle = Bundle.main.bundleIdentifier != nil

    func applicationDidFinishLaunching(_ note: Notification) {
        let info = Bundle.main.infoDictionary ?? [:]
        title = info["CFBundleName"] as? String ?? title
        bakedURL = info["WebAppURL"] as? String ?? "https://example.com/"
        bakedLinks = info["WebAppMenu"] as? [[String: String]] ?? []
        bakedAllowSelfSigned = info["WebAppAllowSelfSignedCerts"] as? Bool ?? false
        bakedKeepRunning = info["WebAppKeepRunning"] as? Bool ?? false
        bakedExternalLinks = info["WebAppExternalLinksInBrowser"] as? Bool ?? false
        bakedUserAgent = info["WebAppUserAgent"] as? String
        bakedInspectable = info["WebAppInspectable"] as? Bool ?? false
        customButtons = parseCustomButtons(info["WebAppButtons"] as? [[String: String]] ?? [])
        injectedCSS = parseInjected(info["WebAppInjectCSS"] as? [[String: String]] ?? [])
        bakedToolbarLayout = (info["WebAppToolbar"] as? [Any]).map(parseToolbarLayout)
            ?? defaultToolbarLayout + customButtons.map { .button($0.name) }
        windowWidth = (info["WebAppWindowWidth"] as? Double).map { CGFloat($0) } ?? 1100
        windowHeight = (info["WebAppWindowHeight"] as? Double).map { CGFloat($0) } ?? 800

        UserDefaults.standard.register(defaults: [
            kWebAppHomeURL: bakedURL,
            kWebAppLinks: bakedLinks,
            kWebAppAllowSelfSigned: bakedAllowSelfSigned,
            kWebAppKeepRunning: bakedKeepRunning,
            kWebAppExternalLinks: bakedExternalLinks,
            kWebAppInspectable: bakedInspectable,
            kWebAppToolbar: toolbarLayoutNames(bakedToolbarLayout),
        ])
        loadFromDefaults()

        if hasBundle {
            let center = UNUserNotificationCenter.current()
            center.delegate = self
            requestNotificationAuthorization()
        }

        let content = WKUserContentController()
        content.add(self, name: "notify")
        content.add(self, name: "webapp") // in-app actions (error page Retry, setButtonState)
        content.addUserScript(WKUserScript(source: assetString("notification-shim.js"),
                                           injectionTime: .atDocumentStart,
                                           forMainFrameOnly: false))
        content.addUserScript(WKUserScript(source: assetString("audio-mute-shim.js"),
                                           injectionTime: .atDocumentStart,
                                           forMainFrameOnly: true))
        content.addUserScript(WKUserScript(source: assetString("bridge-shim.js"),
                                           injectionTime: .atDocumentStart,
                                           forMainFrameOnly: true))
        if !injectedCSS.isEmpty { content.addUserScript(cssInjectionScript(injectedCSS)) }
        for entry in parseInjected(info["WebAppInjectJS"] as? [[String: String]] ?? []) {
            content.addUserScript(jsInjectionScript(entry))
        }

        let config = WKWebViewConfiguration()
        config.userContentController = content
        config.mediaTypesRequiringUserActionForPlayback = []
        config.websiteDataStore = .default() // persistent: keeps logins across launches
        if bakedUserAgent?.isEmpty ?? true {
            config.applicationNameForUserAgent = safariUAToken()
        }

        webView = ShortcutWebView(frame: .zero, configuration: config)
        webView.uiDelegate = self
        webView.navigationDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.allowsMagnification = true // pinch to zoom, ⌘+/- goes over the View menu
        if let ua = bakedUserAgent, !ua.isEmpty { webView.customUserAgent = ua }
        applyInspectable()

        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered, defer: false)
        window.title = title
        window.center()
        window.isReleasedWhenClosed = false
        window.setFrameAutosaveName("WebAppMainWindow")
        window.delegate = self

        let container = NSView(frame: NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight))
        webView.frame = container.bounds
        webView.autoresizingMask = [.width, .height]
        container.addSubview(webView)
        setupFindBar(in: container)
        setupProgressBar(in: container)
        window.contentView = container

        progressObs = webView.observe(\.estimatedProgress, options: [.new]) { [weak self] wv, _ in
            self?.updateProgress(wv.estimatedProgress)
        }
        titleObs = webView.observe(\.title, options: [.new]) { [weak self] _, _ in self?.updateTitle() }
        urlObs = webView.observe(\.url, options: [.new]) { [weak self] _, _ in
            self?.updateTitle()
            if self?.injectedCSS.contains(where: { $0.filter != nil }) == true {
                self?.webView.evaluateJavaScript(
                    "window.__webappUpdateInjectedCSS && window.__webappUpdateInjectedCSS()",
                    completionHandler: nil)
            }
        }
        micObs = webView.observe(\.microphoneCaptureState, options: [.new]) { [weak self] wv, _ in
            DispatchQueue.main.async {
                guard let self else { return }
                if self.micMutePending, wv.microphoneCaptureState == .active {
                    self.micMutePending = false
                    self.toggleMicMute() // .active flips to .muted, emits webapp:muteMic
                    return
                }
                self.updateMuteButtons()
            }
        }

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

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard keepRunning else { return true }
        window.orderOut(nil)
        return false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { showMainWindow() }
        return true
    }

    func applicationDidBecomeActive(_ note: Notification) {
        if keepRunning, let window, !window.isVisible { window.makeKeyAndOrderFront(nil) }
    }

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
        inspectable = d.bool(forKey: kWebAppInspectable)
        toolbarButtons = Set(d.array(forKey: kWebAppToolbar) as? [String] ?? toolbarLayoutNames(bakedToolbarLayout))
    }

    func applyInspectable() {
        if #available(macOS 13.3, *) { webView.isInspectable = inspectable }
    }

    @objc func openSettings() {
        if settings == nil {
            var labels = toolbarButtonLabels
            for b in customButtons { labels[b.name] = b.label }
            settings = SettingsController(defaultLinks: bakedLinks, defaultHomeURL: bakedURL,
                                          defaultAllowSelfSigned: bakedAllowSelfSigned,
                                          defaultKeepRunning: bakedKeepRunning,
                                          defaultExternalLinks: bakedExternalLinks,
                                          defaultInspectable: bakedInspectable,
                                          defaultToolbar: toolbarLayoutNames(bakedToolbarLayout),
                                          toolbarLabels: labels) { [weak self] in
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
        applyInspectable()
    }

    // MARK: shared UI helpers

    func symbol(_ name: String, _ desc: String) -> NSImage {
        NSImage(systemSymbolName: name, accessibilityDescription: desc) ?? NSImage()
    }

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
